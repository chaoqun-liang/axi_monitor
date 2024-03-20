// to-do: take out queue, pass linked-data-t to it from wr/rd guard
// add another remapper for repsonse
module write_guard #(
  parameter int unsigned MaxUniqIds = 0,
  parameter int unsigned MaxWrTxns = 0, 
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
  input  cnt_t       budget_awvld_awrdy_i,
  input  cnt_t       budget_awvld_wvld_i,
  input  cnt_t       budget_wvld_wrdy_i,
  input  cnt_t       budget_wvld_wlast_i,
  input  cnt_t       budget_wlast_bvld_i,
  input  cnt_t       budget_wlast_brdy_i
  /// Latency in clock cycles can also be available 
  // output cnt_t   latency_awvld_awrdy_o,
  // output cnt_t   latency_awvld_wvld_o,
  // output cnt_t   latency_wvld_wrdy_o,
  // output cnt_t   latency_wvld_wlast_o,
  // output cnt_t   latency_wlast_bvld_o,
  // output cnt_t   latency_wlast_brdy_o
);
  id_t  [MaxWrTxns-1:0]   oup_id;

  assign hw2reg_o.irq.mis_id_wr.de = 1'b1;
  assign hw2reg_o.irq.w0.de = 1'b1;
  assign hw2reg_o.irq.w1.de = 1'b1;
  assign hw2reg_o.irq.w2.de = 1'b1;
  assign hw2reg_o.irq.w3.de = 1'b1;
  assign hw2reg_o.irq.w4.de = 1'b1;
  assign hw2reg_o.irq.w5.de = 1'b1;
  assign hw2reg_o.irq_addr.de = 1'b1;
  assign hw2reg_o.reset.de = 1'b1; 

  // Capacity of the head-tail table, which associates an ID with corresponding head and tail indices.
  localparam int HtCapacity = (MaxUniqIds <= MaxWrTxns) ? MaxUniqIds : MaxWrTxns;
  localparam int unsigned HtIdxWidth = cf_math_pkg::idx_width(HtCapacity);
  localparam int unsigned LdIdxWidth = cf_math_pkg::idx_width(MaxWrTxns);

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
    logic [CntWidth -1:0] cnt_awvalid_awready; // AWVALID to AWREADY
    logic [CntWidth -1:0] cnt_awvalid_wfirst;  // AWVALID to WFIRST
    logic [CntWidth -1:0] cnt_wvalid_wready_first; // WVALID to WREADY of WFIRST
    logic [CntWidth -1:0] cnt_wfirst_wlast;    // WFIRST to WLAST
    logic [CntWidth -1:0] cnt_wlast_bvalid;    // WLAST to BVALID
    logic [CntWidth  -1:0] cnt_wlast_bready;   // WLAST to BREADY
  } write_cnters_t;

  // state enum of the FSM
  typedef enum logic [2:0] {
    IDLE,
    WRITE_ADDRESS,
    WRITE_DATA,
    WRITE_RESPONSE,
    WRITE_TIMEOUT
  } write_state_t;

  // Type of an entry in the linked data table.
  typedef struct packed {
    aw_chan_t      metadata;
    id_t           id;
    ld_idx_t       next;
    write_state_t  write_state;
    write_cnters_t counters; 
    logic          free;
  } linked_data_t;

  head_tail_t [HtCapacity-1:0]    head_tail_d,    head_tail_q;
    
  // Array of linked data
  linked_data_t [MaxWrTxns-1:0]    linked_data_d,  linked_data_q;
  //linked_data_q.metadata = req_i.aw;

  logic                           full,
                                  match_in_id_valid,
                                  match_out_id_valid,
                                  no_in_id_match,
                                  no_out_id_match;

  logic [HtCapacity-1:0]          head_tail_free,
                                  idx_matches_in_id,
                                  idx_matches_out_id;

  logic [MaxWrTxns-1:0]           linked_data_free, timeout_detected,reset_req, irq;

  id_t                            match_in_id, match_out_id;

  ht_idx_t                        head_tail_free_idx,
                                  match_in_idx,
                                  match_out_idx;

  ld_idx_t                        linked_data_free_idx,
                                  oup_data_free_idx;

  logic                           oup_data_popped,
                                  oup_ht_popped;
  
  logic [MaxWrTxns-1:0]                           oup_req;
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
  for (genvar i = 0; i < MaxWrTxns; i++) begin: gen_linked_data_free
    assign linked_data_free[i] = linked_data_q[i].free;
  end

  lzc #(
    .WIDTH ( MaxWrTxns ),
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
        oup_data_popped = 1;
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
      // // else begin 
      // // //If there was no match, interrupt with non-requested transactions
      // // Always grant the output request.
       oup_gnt_o = 1'b1;
      // // end
    end

    if (inp_req_i && inp_gnt_o) begin
      match_in_id = mst_req_i.aw.id;
      match_in_id_valid = 1'b1;
      // If the ID does not yet exist in the queue or was just popped, add a new ID entry.
      if (oup_ht_popped && (oup_id== mst_req_i.aw.id)) begin
        // If output data was popped for this ID, which lead the head_tail to be popped,
        // then repopulate this head_tail immediately.
        head_tail_d[match_out_idx] = '{
          id: mst_req_i.aw.id,
          head: oup_data_free_idx,
          tail: oup_data_free_idx,
          free: 1'b0
        };
        linked_data_d[oup_data_free_idx] = '{
          metadata: mst_req_i.aw,
          next: '0,
          free: 1'b0,
          id: mst_req_i.aw.id,
          write_state: IDLE,
          counters: 0
        };
      end else if (no_in_id_match) begin
        // Else, if no head_tail corresponds to the input id.
        if (oup_ht_popped) begin
          head_tail_d[match_out_idx] = '{
            id: mst_req_i.aw.id,
            head: oup_data_free_idx,
            tail: oup_data_free_idx,
            free: 1'b0
          };
          linked_data_d[oup_data_free_idx] = '{
            metadata: mst_req_i.aw,
            next: '0,
            free: 1'b0,
            id: mst_req_i.aw.id,
            write_state: IDLE,
            counters: 0
          };
        end else begin
          if (oup_data_popped) begin
            head_tail_d[head_tail_free_idx] = '{
              id: mst_req_i.aw.id,
              head: oup_data_free_idx,
              tail: oup_data_free_idx,
              free: 1'b0
            };
            linked_data_d[oup_data_free_idx] = '{
              metadata: mst_req_i.aw,
              next: '0,
              id: mst_req_i.aw.id,
              write_state: IDLE,
              counters: 0, 
              free: 1'b0
            };
            end else begin
              head_tail_d[head_tail_free_idx] = '{
                id: mst_req_i.aw.id,
                head: linked_data_free_idx,
                tail: linked_data_free_idx,
                free: 1'b0
              };
              linked_data_d[linked_data_free_idx] = '{
                metadata: mst_req_i.aw,
                next: '0,
                id: mst_req_i.aw.id,
                write_state: IDLE,
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
            metadata: mst_req_i.aw,
            next: '0,
            id: mst_req_i.aw.id,
            write_state: IDLE,
            counters: 0, 
            free: 1'b0
          };
        end else begin
          linked_data_d[head_tail_q[match_in_idx].tail].next = linked_data_free_idx;
          head_tail_d[match_in_idx].tail = linked_data_free_idx;
          linked_data_d[linked_data_free_idx] = '{
            metadata: mst_req_i.aw,
            next: '0,
            id: mst_req_i.aw.id,
            write_state: IDLE,
            counters: 0, 
            free: 1'b0
          };
        end
      end
    end
  end

  // HT table registers
  for (genvar i = 0; i < HtCapacity; i++) begin: gen_ht_ffs
    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni) begin
        head_tail_q[i] <= '{free: 1'b1, default: '0};
      end else begin
        head_tail_q[i] <= head_tail_d[i];
      end
    end
  end
  
  /// default bypass
  /// AW channel
  assign slv_req_o.aw_valid = guard_ena_i ? (mst_req_i.aw_valid && !timeout_detected) : mst_req_i.aw_valid;
  assign mst_rsp_o.aw_ready = guard_ena_i ? (slv_rsp_i.aw_ready || timeout_detected) : slv_rsp_i.aw_ready;
  assign slv_req_o.aw = guard_ena_i ? (mst_req_i.aw && !timeout_detected) : mst_req_i.aw;
  /// W channel
  assign slv_req_o.w_valid = guard_ena_i ? (mst_req_i.w_valid && !timeout_detected) : mst_req_i.w_valid;
  assign mst_rsp_o.w_ready = guard_ena_i ? (slv_rsp_i.w_ready || timeout_detected) : slv_rsp_i.w_ready;
  assign slv_req_o.w = guard_ena_i ? (mst_req_i.w && !timeout_detected) : mst_req_i.w;
  /// B channel
  assign mst_rsp_o.b_valid = guard_ena_i ? (slv_rsp_i.b_valid && !timeout_detected) : slv_rsp_i.b_valid;
  assign slv_req_o.b_ready = guard_ena_i ? (mst_req_i.b_ready || timeout_detected) : mst_req_i.b_ready;
  assign mst_rsp_o.b = guard_ena_i ? (slv_rsp_i.b && !timeout_detected) : slv_rsp_i.b;
 
  for (genvar i = 0; i < MaxWrTxns; i++) begin
  /// state transitions and counter updates
   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
      // Reset for all slots
      linked_data_q[i] <= {'0,1'b1};
      //linked_data_q[i] <= '0;
       // linked_data_q[i][0] <= 1'b1;//????????????????????????????
      end else begin
      //if (guard_ena_i) begin
          linked_data_q[i]   <= linked_data_d[i];
          if (!linked_data_q[i].free) begin // only if slot is in use
          case (linked_data_q[i].write_state) 
              IDLE: begin
                if (mst_req_i.aw_valid) begin // aw_valid enables enqueue into the ID queue
                  linked_data_q[i].write_state <= WRITE_ADDRESS;
                end
              end

              WRITE_ADDRESS: begin
                if (!slv_rsp_i.aw_ready && mst_req_i.aw_valid) begin
                  linked_data_q[i].counters.cnt_awvalid_awready++;
                end
                linked_data_q[i].counters.cnt_awvalid_wfirst++;
                if (mst_req_i.w_valid ) begin
                  linked_data_q[i].write_state <= WRITE_DATA;
                end
                  
                if (linked_data_q[i].counters.cnt_awvalid_awready >= budget_awvld_awrdy_i 
                || linked_data_q[i].counters.cnt_awvalid_wfirst  >= budget_awvld_wvld_i) begin
                  linked_data_q[i].write_state <= WRITE_TIMEOUT;
              
                end
              end

              WRITE_DATA: begin
                if (!slv_rsp_i.w_ready && mst_req_i.w_valid) begin
                  linked_data_q[i].counters.cnt_wvalid_wready_first++;
                end
                linked_data_q[i].counters.cnt_wfirst_wlast++;
                  
                if (mst_req_i.w.last) begin
                  linked_data_q[i].write_state <= WRITE_RESPONSE;
                end
                  
                if (linked_data_q[i].counters.cnt_wvalid_wready_first >= budget_wvld_wrdy_i 
                || linked_data_q[i].counters.cnt_wfirst_wlast  >= budget_wvld_wlast_i) begin
                  linked_data_q[i].write_state <= WRITE_TIMEOUT;
                
                end
              end

                WRITE_RESPONSE: begin
                  if (!slv_rsp_i.b_valid) begin
                    linked_data_q[i].counters.cnt_wlast_bvalid++;
                  end
                  linked_data_q[i].counters.cnt_wlast_bready++;
                    
                  if (mst_req_i.b_ready) begin
                    oup_id[i] <= slv_rsp_i.b.id;
                    oup_req[i] <= 1'b1;
                    linked_data_q[i].counters <= '0;
                    if (linked_data_q[i].metadata.id == slv_rsp_i.b.id) begin
                      linked_data_q[i].write_state <= IDLE;
                    end else begin
                      irq[i] <= 1'b1;
                     // hw2reg_o.irq.mis_id_wr.d <= 1'b1;
                     // mst_rsp_o.b.resp <= 2'b10; 
                      linked_data_q[i]    <= {'0,1'b1};
                      // linked_data_q[i][0] <= 1'b1;//????????????????????????????
                      reset_req[i]  <= 1'b1;
                      //hw2reg_o.irq.txn_id.d <= linked_data_q[i].metadata.id;
                      //hw2reg_o.irq_addr.d <= linked_data_q[i].metadata.address;
                    end 
                  end

                  if (linked_data_q[i].counters.cnt_wlast_bvalid >= budget_wlast_bvld_i 
                  || linked_data_q[i].counters.cnt_wlast_bready >= budget_wlast_brdy_i ) begin
                    linked_data_q[i].write_state <= WRITE_TIMEOUT;
        
                   end
                end

            WRITE_TIMEOUT: begin
              irq[i] <= 1'b1;
              //hw2reg_o. <= 1'b1;
             // mst_rsp_o.b.resp = 2'b10;
              linked_data_q[i]    <= {'0,1'b1};
              // linked_data_q[i][0] <= 1'b1;//????????????????????????????
              reset_req[i]  <= 1'b1;
              timeout_detected[i]  <= 1'b1;
             
            end
          endcase
        end
      end
    //end
    end
  end

      // Validate parameters.
`ifndef SYNTHESIS
`ifndef COMMON_CELLS_ASSERTS_OFF
    initial begin: validate_params
        // assert (ID_WIDTH >= 1)
        //     else $fatal(1, "The ID must at least be one bit wide!");
        assert (MaxWrTxns >= 1)
            else $fatal(1, "The queue must have capacity of at least one entry!");
    end
`endif
`endif
endmodule

// non-requested transactions: exists check in id queue ?
// look up in id queue with response id
// ht table is necessary to avoid looking up in the linked data table one by one
// which is less efficient
 // hw2reg_o.irq.txn_id.d <= linked_data_q[i].metadata.id;
 // hw2reg_o.irq_addr.d <= linked_data_q[i].metadata.address;