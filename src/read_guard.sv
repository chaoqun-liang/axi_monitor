// 
module read_guard #(
  parameter int unsigned IdWidth  = 0,
  parameter int unsigned MaxRdTxns  = 0,
  parameter int unsigned LatencyWidth = 0,
  parameter int unsigned CntWidth = 0,
  parameter type req_t = logic,
  parameter type rsp_t = logic,
  parameter type cnt_t = logic,
  parameter type id_t  = logic,
  parameter type aw_chan_t = logic,
  parameter type reg2hw_t = logic,
  parameter type hw2reg_t = logic
)(
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic       guard_ena_i,
  
  input  req_t       mst_req_i,  
  output rsp_t       mst_rsp_o,
  input  rsp_t       slv_rsp_i,
  output req_t       slv_req_o,
  
  input  logic       inp_req_i, 
  output logic       inp_gnt_o,

  output logic       oup_data_valid_o,
  output logic       oup_gnt_o,
  
  output logic       reset_req_o,
  output logic       irq_o,

  // register configs
  input  reg2hw_t    reg2hw_i,
  output hw2reg_t    hw2reg_o,
  /// Latency budget
  input  cnt_t   budget_arvld_arrdy_i,
  input  cnt_t   budget_arvld_rvld_i,
  input  cnt_t   budget_rvld_rrdy_i,
  input  cnt_t   budget_rvld_rlast_i
);
  
  id_t  [MaxRdTxns-1:0]   oup_id;

  assign hw2reg_o.irq.mis_id_rd.de = 1'b1;
  assign hw2reg_o.irq.r0.de = 1'b1;
  assign hw2reg_o.irq.r1.de = 1'b1;
  assign hw2reg_o.irq.r2.de = 1'b1;
  assign hw2reg_o.irq.r3.de = 1'b1;
  assign hw2reg_o.irq_addr.de = 1'b1;
  assign hw2reg_o.reset.de = 1'b1; 
  
  // Capacity of the head-tail table, which associates an ID with corresponding head and tail indices.
  localparam int NumIds = 2**IdWidth;
  localparam int HtCapacity = (NumIds <= MaxRdTxns) ? NumIds : MaxRdTxns;
  localparam int unsigned HtIdxWidth = cf_math_pkg::idx_width(HtCapacity);
  localparam int unsigned LdIdxWidth = cf_math_pkg::idx_width(MaxRdTxns);

  // Type for indexing the head-tail table.
  typedef logic [HtIdxWidth-1:0] ht_idx_t;

  // Type for indexing the lined data table.
  typedef logic [LdIdxWidth-1:0] ld_idx_t;

  // Type of an entry in the head-tail table.
  typedef struct packed {
    id_t        id;
    ld_idx_t    head,
                tail;
    logic       free;
  } head_tail_t;

  typedef struct packed {
    logic [LatencyWidth -1:0] cnt_arvalid_arready; // ARVALID to ARREADY
    logic [LatencyWidth -1:0] cnt_arvalid_rfirst;  // ARVALID to RFIRST
    logic [LatencyWidth -1:0] cnt_rvalid_rready;   // RVALID to RREADY
    logic [LatencyWidth -1:0] cnt_rvalid_rlast;    // RVALID to RLAST
  } read_cnters_t;

  // state enum of the FSM
  typedef enum logic [2:0] {
    IDLE,
    READ_ADDRESS,
    READ_DATA,
    READ_RESPONSE,
    READ_TIMEOUT
  } read_state_t;

  // Type of an entry in the linked data table.
  typedef struct packed {
    aw_chan_t      metadata;
    id_t           id;
    ld_idx_t       next;
    read_state_t   read_state;
    read_cnters_t  counters; 
    logic          free;
  } linked_data_t;

  head_tail_t [HtCapacity-1:0]    head_tail_d,    head_tail_q;
    
  // Array of linked data
  linked_data_t [MaxRdTxns-1:0]    linked_data_d,  linked_data_q;
  //linked_data_q.metadata = req_i.aw;

  logic                           full,
                                  match_in_id_valid,
                                  match_out_id_valid,
                                  no_in_id_match,
                                  no_out_id_match;

  logic [HtCapacity-1:0]          head_tail_free,
                                  idx_matches_in_id,
                                  idx_matches_out_id;

  logic [MaxRdTxns-1:0]           linked_data_free,timeout_detected,reset_req,irq;

  id_t                            match_in_id, match_out_id;

  ht_idx_t                        head_tail_free_idx,
                                  match_in_idx,
                                  match_out_idx;

  ld_idx_t                        linked_data_free_idx,
                                  oup_data_free_idx;

  logic                           oup_data_popped,
                                  oup_ht_popped;
  
  logic [MaxRdTxns-1:0]           oup_req;
  // Find the index in the head-tail table that matches a given ID.
  for (genvar i = 0; i < HtCapacity; i++) begin: gen_idx_match
    assign idx_matches_in_id[i] = match_in_id_valid && (head_tail_q[i].id == match_in_id) && !head_tail_q[i].free;
    assign idx_matches_out_id[i] = match_out_id_valid && (head_tail_q[i].id == match_out_id) && !head_tail_q[i].free;
  end
    
  assign no_in_id_match = !(|idx_matches_in_id);
  assign no_out_id_match = !(|idx_matches_out_id);

  onehot_to_bin #(
    .ONEHOT_WIDTH ( HtCapacity )
  ) i_id_ohb_in (
    .onehot ( idx_matches_in_id ),
    .bin    ( match_in_idx      )
  );
  onehot_to_bin #(
    .ONEHOT_WIDTH ( HtCapacity )
  ) i_id_ohb_out (
    .onehot ( idx_matches_out_id ),
    .bin    ( match_out_idx      )
  );

  // Find the first free index in the head-tail table.
  for (genvar i = 0; i < HtCapacity; i++) begin: gen_head_tail_free
    assign head_tail_free[i] = head_tail_q[i].free;
  end

  lzc #(
    .WIDTH ( HtCapacity ),
    .MODE  ( 0          ) // Start at index 0.
  ) i_ht_free_lzc (
    .in_i    ( head_tail_free     ),
    .cnt_o   ( head_tail_free_idx ),
    .empty_o (                    )
  );

  // Find the first free index in the linked data table.
  for (genvar i = 0; i < MaxRdTxns; i++) begin: gen_linked_data_free
    assign linked_data_free[i] = linked_data_q[i].free;
  end

  lzc #(
    .WIDTH ( MaxRdTxns ),
    .MODE  ( 0        ) // Start at index 0.
  ) i_ld_free_lzc (
        .in_i    ( linked_data_free     ),
        .cnt_o   ( linked_data_free_idx ),
        .empty_o (                      )
  );

  // The queue is full if and only if there are no free items in the linked data structure.
  assign full = !(|linked_data_free);
  // Data potentially freed by the output.
  assign oup_data_free_idx = head_tail_q[match_out_idx].head;

  // Data can be accepted if the linked list pool is not full, or some data is simultaneously.
  assign inp_gnt_o = ~full || oup_data_popped;
  always_comb begin
    match_in_id         = '0;
    match_out_id        = '0;
    match_in_id_valid   = 1'b0;
    match_out_id_valid  = 1'b0;
    head_tail_d         = head_tail_q;
    linked_data_d       = linked_data_q;
    oup_gnt_o           = 1'b0;
    oup_data_valid_o    = 1'b0;
    oup_data_popped     = 1'b0;
    oup_ht_popped       = 1'b0;
        
    // FULL_BW Input and output can be performed simultaneously and a popped cell can be reused immediately in the same clock cycle.
    if (oup_req) begin
      match_out_id = oup_id;
      match_out_id_valid = 1'b1;
      if (!no_out_id_match) begin
        oup_data_valid_o = 1'b1;
        oup_data_popped = 1'b1;
        // Set free bit of linked data entry, all other bits are don't care.
        linked_data_d[head_tail_q[match_out_idx].head]      = {'0,1'b1};
        // linked_data_d[head_tail_q[match_out_idx].head]      = '0;
        // linked_data_d[head_tail_q[match_out_idx].head][0]   = 1'b1;
        /// If it is the last cell of this ID
        if (head_tail_q[match_out_idx].head == head_tail_q[match_out_idx].tail) begin
          oup_ht_popped = 1'b1;
          head_tail_d[match_out_idx] = '{free: 1'b1, default: '0};
        end else begin
          head_tail_d[match_out_idx].head = linked_data_q[head_tail_q[match_out_idx].head].next;
        end
      end
      // Always grant the output request.  If there was no match, the default, invalid entry will be returned.
      oup_gnt_o = 1'b1;
    end

    if (inp_req_i && inp_gnt_o) begin
      match_in_id = mst_req_i.ar.id;
      match_in_id_valid = 1'b1;
      // If the ID does not yet exist in the queue or was just popped, add a new ID entry.
      if (oup_ht_popped && (oup_id==mst_req_i.ar.id)) begin
        // If output data was popped for this ID, which lead the head_tail to be popped,
        // then repopulate this head_tail immediately.
        head_tail_d[match_out_idx] = '{
          id: mst_req_i.ar.id,
          head: oup_data_free_idx,
          tail: oup_data_free_idx,
          free: 1'b0
        };
        linked_data_d[oup_data_free_idx] = '{
          metadata: mst_req_i.ar,
          next: '0,
          free: 1'b0,
          id: mst_req_i.ar.id,
          read_state: IDLE,
          counters: 0
        };
      end else if (no_in_id_match) begin
        // Else, if no head_tail corresponds to the input id.
        if (oup_ht_popped) begin
          head_tail_d[match_out_idx] = '{
            id: mst_req_i.ar.id,
            head: oup_data_free_idx,
            tail: oup_data_free_idx,
            free: 1'b0
          };
          linked_data_d[oup_data_free_idx] = '{
            metadata: mst_req_i.ar,
            next: '0,
            free: 1'b0,
            id: mst_req_i.ar.id,
            read_state: IDLE,
            counters: 0
          };
        end else begin
          if (oup_data_popped) begin
            head_tail_d[head_tail_free_idx] = '{
              id: mst_req_i.ar.id,
              head: oup_data_free_idx,
              tail: oup_data_free_idx,
              free: 1'b0
            };
            linked_data_d[oup_data_free_idx] = '{
              metadata: mst_req_i.ar,
              next: '0,
              id: mst_req_i.ar.id,
              read_state: IDLE,
              counters: 0, 
              free: 1'b0
            };
            end else begin
              head_tail_d[head_tail_free_idx] = '{
                id: mst_req_i.ar.id,
                head: linked_data_free_idx,
                tail: linked_data_free_idx,
                free: 1'b0
              };
              linked_data_d[linked_data_free_idx] = '{
                metadata: mst_req_i.ar,
                next: '0,
                id: mst_req_i.ar.id,
                read_state: IDLE,
                counters: 0, 
                free: 1'b0
              };
            end
        end
      end else begin
        // Otherwise append it to the existing ID subqueue.
        if (oup_data_popped) begin
          linked_data_d[head_tail_q[match_in_idx].tail].next = oup_data_free_idx;
          head_tail_d[match_in_idx].tail = oup_data_free_idx;
          linked_data_d[oup_data_free_idx] = '{
            metadata: mst_req_i.ar,
            next: '0,
            id: mst_req_i.ar.id,
            read_state: IDLE,
            counters: 0, 
            free: 1'b0
          };
        end else begin
          linked_data_d[head_tail_q[match_in_idx].tail].next = linked_data_free_idx;
            head_tail_d[match_in_idx].tail = linked_data_free_idx;
            linked_data_d[linked_data_free_idx] = '{
              metadata: mst_req_i.ar,
              next: '0,
              id: mst_req_i.ar.id,
              read_state: IDLE,
              counters: 0, 
              free: 1'b0
            };
        end
      end
    end
  end

  // Registers
  for (genvar i = 0; i < HtCapacity; i++) begin: gen_ht_ffs
    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni) begin
        head_tail_q[i] <= '{free: 1'b1, default: '0};
        end else begin
          head_tail_q[i] <= head_tail_d[i];
        end
    end
  end

  /// default signal pass-through
  /// AR channel
  assign slv_req_o.ar_valid = guard_ena_i ? (mst_req_i.ar_valid && !timeout_detected) : mst_req_i.ar_valid;
  assign mst_rsp_o.ar_ready = guard_ena_i ? (slv_rsp_i.ar_ready || timeout_detected) : slv_rsp_i.ar_ready;
  assign slv_req_o.ar = guard_ena_i ? (mst_req_i.ar && !timeout_detected) : mst_req_i.ar;
  /// R channel
  assign mst_rsp_o.r_valid = guard_ena_i ? (slv_rsp_i.r_valid && !timeout_detected) : slv_rsp_i.r_valid;
  assign slv_req_o.r_ready = guard_ena_i ? (mst_req_i.r_ready || timeout_detected) : mst_req_i.r_ready;
  assign mst_rsp_o.r = guard_ena_i ? (slv_rsp_i.r && !timeout_detected) : slv_rsp_i.r;
  
  for (genvar i = 0; i < MaxRdTxns; i++) begin
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // Reset for all slots
      linked_data_q[i] <= {'0,1'b1};
      // linked_data_q[i].free <= 1'b1; 
      // linked_data_q[i].counters <= '0;
    end else begin
       linked_data_q[i]   <= linked_data_d[i];
       if (!linked_data_q[i].free) begin // only if slot is in use
        case (linked_data_q[i].read_state)
            IDLE: begin
              if (mst_req_i.ar_valid) begin // AR_VALID enables enqueue into the ID queue
                linked_data_q[i].read_state <= READ_ADDRESS;
              end
            end

            READ_ADDRESS: begin
              if (!slv_rsp_i.ar_ready && mst_req_i.ar_valid) begin
                linked_data_q[i].counters.cnt_arvalid_arready++;
              end
              linked_data_q[i].counters.cnt_arvalid_rfirst++;
              if (slv_rsp_i.r_valid) begin
                linked_data_q[i].read_state <= READ_DATA;
              end
                
              if (linked_data_q[i].counters.cnt_arvalid_arready >= budget_arvld_arrdy_i 
              || linked_data_q[i].counters.cnt_arvalid_rfirst  >= budget_arvld_rvld_i) begin
                linked_data_q[i].read_state <= READ_TIMEOUT;
              end
            end

            READ_RESPONSE: begin
              if (!slv_rsp_i.r_last && mst_req_i.r_valid) begin
                linked_data_q[i].counters.cnt_rvalid_rlast++;
              end
              linked_data_q[i].counters.cnt_rvalid_rready++;

              if (req_i.r_ready) begin
                oup_id <= rsp_i.r.id;
                oup_req <= 1'b1;
                linked_data_q[i].counters <= '0;
                if (linked_data_q[i].metadata.ar.id == rsp_i.r.id) begin
                  linked_data_q[i].read_state <= IDLE;
                end else begin
                  irq_o <= 1'b1;
                  hw2reg_o.mis_id_rd.d <= 1'b1;
                  rsp_o.b_resp <= 2'b10; 
                  linked_data_q[i].read_state <= IDLE;
                  linked_data_q[i].free <= 1'b1;
                  linked_data_q[i].counters <= '0;
                  reset_req_o <= 1'b1;
                  // hw2reg_o.txn_id <= linked_data_q[i].metadata.id;
                  // hw2reg_o.irq_addr <= linked_data_q[i].metadata.address;
                end 
              end
               
              if (linked_data_q[i].counters.cnt_rvalid_rready >= budget_rvld_rrdy_i 
              || linked_data_q[i].counters.cnt_rvalid_rlast >= budget_rvld_rlast_i ) begin
                linked_data_q[i].read_state <=   READ_TIMEOUT;
              end
            end

            READ_TIMEOUT: begin
              irq_o <= 1'b1;
             // hw2reg_o. <= 1'b1;
              linked_data_q[i].read_state <= IDLE;
              linked_data_q[i].free <= 1'b1;
              linked_data_q[i].counters <= '0;
              reset_req_o <= 1'b1;
              hw2reg_o.txn_id <= linked_data_q[i].metadata.id;
              hw2reg_o.irq_addr <= linked_data_q[i].metadata.address;
            end
          endcase
        end
      end
    end
  end









endmodule