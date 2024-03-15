// 
module read_guard #(
  parameter int unsigned IdWidth  = 0,
  parameter int unsigned MaxRdTxns  = 0,
  parameter int unsigned LatencyWidth = 0,
  parameter type data_t   = logic,
  parameter type aw_chan_t = logic,
  parameter type req_t = logic,
  // Dependent params, DO NOT OVERRIDE!
  localparam type latency_t = logic[LatencyWidth-1:0],
  localparam type id_t  = logic[IdWidth-1:0]
)(
  input  logic       clk_i,
  input  logic       rst_ni,
  
  input  req_t       req_i,  
  input  rsp_t       rsp_i,
  
  input  logic       inp_req_i, 
  output logic       inp_gnt_o,

  output req_t       req_o,
  output rsp_t       rsp_o,
  input  logic       oup_req_i,
  output logic       oup_data_valid_o,
  output logic       oup_gnt_o,
  /// Latency budget
  input  latency_t   budget_arvld_arrdy_i,
  input  latency_t   budget_arvld_rvld_i,
  input  latency_t   budget_rvld_rrdy_i,
  input  latency_t   budget_rvld_rlast_i
);
  
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
  typedef enum logic [1:0] {
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
    logic          free;
    read_state_t   read_state;
    read_cnters_t  counters; 
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

  logic [MaxRdTxns-1:0]             linked_data_free;

  id_t                            match_in_id, match_out_id;

  ht_idx_t                        head_tail_free_idx,
                                  match_in_idx,
                                  match_out_idx;

  ld_idx_t                        linked_data_free_idx,
                                  oup_data_free_idx;

  logic                           oup_data_popped,
                                  oup_ht_popped;

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
    oup_data_o          = data_t'('0);
    oup_data_valid_o    = 1'b0;
    oup_data_popped     = 1'b0;
    oup_ht_popped       = 1'b0;
        
    // FULL_BW Input and output can be performed simultaneously and a popped cell can be reused immediately in the same clock cycle.
    if (oup_req_i) begin
      match_out_id = oup_id;
      match_out_id_valid = 1'b1;
      if (!no_out_id_match) begin
        oup_data_o = data_t'(linked_data_q[head_tail_q[match_out_idx].head].data);
        oup_data_valid_o = 1'b1;
        
        oup_data_popped = 1'b1;
        // Set free bit of linked data entry, all other bits are don't care.
        linked_data_d[head_tail_q[match_out_idx].head]      = '0;
        linked_data_d[head_tail_q[match_out_idx].head][0]   = 1'b1;
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
      match_in_id = req_i.aw.id;
      match_in_id_valid = 1'b1;
      // If the ID does not yet exist in the queue or was just popped, add a new ID entry.
      if (oup_ht_popped && (oup_id==req_i.aw.id)) begin
        // If output data was popped for this ID, which lead the head_tail to be popped,
        // then repopulate this head_tail immediately.
        head_tail_d[match_out_idx] = '{
          id: req_i.aw.id,
          head: oup_data_free_idx,
          tail: oup_data_free_idx,
          free: 1'b0
        };
        linked_data_d[oup_data_free_idx] = '{
          metadata: req_i.aw,
          next: '0,
          free: 1'b0
        };
      end else if (no_in_id_match) begin
        // Else, if no head_tail corresponds to the input id.
        if (oup_ht_popped) begin
          head_tail_d[match_out_idx] = '{
            id: req_i.aw.id,
            head: oup_data_free_idx,
            tail: oup_data_free_idx,
            free: 1'b0
          };
          linked_data_d[oup_data_free_idx] = '{
            metadata: req_i.aw,
            next: '0,
            free: 1'b0
          };
        end else begin
          if (oup_data_popped) begin
            head_tail_d[head_tail_free_idx] = '{
              id: req_i.aw.id,
              head: oup_data_free_idx,
              tail: oup_data_free_idx,
              free: 1'b0
            };
            linked_data_d[oup_data_free_idx] = '{
              metadata: req_i.aw,
              next: '0,
              free: 1'b0
            };
            end else begin
              head_tail_d[head_tail_free_idx] = '{
                id: req_i.aw.id,
                head: linked_data_free_idx,
                tail: linked_data_free_idx,
                free: 1'b0
              };
              linked_data_d[linked_data_free_idx] = '{
                metadata: req_i.aw,
                next: '0,
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
            metadata: req_i.aw,
            next: '0,
            free: 1'b0
          };
        end else begin
          linked_data_d[head_tail_q[match_in_idx].tail].next = linked_data_free_idx;
            head_tail_d[match_in_idx].tail = linked_data_free_idx;
            linked_data_d[linked_data_free_idx] = '{
              metadata: req_i.aw,
              next: '0,
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
  assign req_o.ar_valid = guard_ena_i ? (req_i.ar_valid && !timeout_detected) : req_i.ar_valid;
  assign req_i.ar_ready = guard_ena_i ? (req_o.ar_ready || timeout_detected) : req_o.ar_ready;
  assign req_o.ar = guard_ena_i ? (req_i.ar && !timeout_detected) : req_i.ar;
  /// R channel
  assign rsp_o.r_valid = guard_ena_i ? (rsp_i.r_valid && !timeout_detected) : rsp_i.r_valid;
  assign rsp_i.r_ready = guard_ena_i ? (rsp_o.r_ready || timeout_detected) : rsp_o.r_ready;
  assign rsp_o.r = guard_ena_i ? (rsp_i.r && !timeout_detected) : rsp_i.r;
  

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // Reset for all slots
      for (int i = 0; i < MaxRdTxns; i++) begin
        linked_data_q[i].state <= IDLE;
        linked_data_q[i].free <= 1'b1; 
        linked_data_q[i].counters <= '0;
      end
    end else begin
      for (genvar i = 0; i < MaxRdTxns; i++) begin
        if (!linked_data_q[i].free) begin // only if slot is in use
          linked_data_q[i]    <= linked_data_d[i];
          case (linked_data_q[i].state)
            IDLE: begin
              if (ar_valid) begin // AR_VALID enables enqueue into the ID queue
                linked_data_q[i].state <= READ_ADDRESS;
              end
            end

            READ_ADDRESS: begin
              if (!rsp_i.ar_ready && req_i.ar_valid) begin
                linked_data_q[i].cnt_arvalid_arready++;
              end
              linked_data_q[i].cnt_arvalid_rfirst++;
              if (req_i.w_valid) begin
                linked_data_q[i].state <= READ_DATA;
              end
                
              if (linked_data_q[i].cnt_arvalid_arready >= budget_arvld_arrdy 
              || linked_data_q[i].cnt_arvalid_rfirst  >= budget_arvld_rvld) begin
                linked_data_q[i].state <= READ_TIMEOUT;
              end
            end

            READ_RESPONSE: begin
              if (!rsp_i.r_last && req_i.r_valid) begin
                linked_data_q[i].cnt_rvalid_rlast++;
              end
              linked_data_q[i].cnt_rvalid_rready++;
                
              if (req_i.r_ready) begin
                oup_id <= rsp_i.r.id;
                oup_req <= 1'b1;
                linked_data_q[i].counters <= '0;
                if (linked_data_q[i].metadata.ar.id == rsp_i.r.id) begin
                  linked_data_q[i].state <= IDLE;
                end else begin
                  irq_o <= 1'b1;
                  hw2reg_o.mis_id_rd.d <= 1'b1;
                  rsp_o.b_resp <= 2'b10; 
                  linked_data_q[i].state <= IDLE;
                  linked_data_q[i].free <= 1'b1;
                  linked_data_q[i].counters <= '0;
                  reset_req_o <= 1'b1;
                  hw2reg_o.txn_id <= linked_data_q[i].metadata.id;
                  hw2reg_o.irq_addr <= linked_data_q[i].metadata.address;
                end 
               
              if (linked_data_q[i].cnt_rvalid_rready >= budget_rvld_rrdy 
              || linked_data_q[i].cnt_rvalid_rlast >= budget_rvld_rlast ) begin
                linked_data_q[i].state <=   READ_TIMEOUT;
              end
            end

            READ_TIMEOUT: begin
              irq_o <= 1'b1;
              hw2reg_o. <= 1'b1;
              rsp_o.r_resp = 2'b10;
              linked_data_q[i].state <= IDLE;
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
end








endmodule