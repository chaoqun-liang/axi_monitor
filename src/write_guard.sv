/// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

module write_guard #(
  // Maximum number of unique IDs
  parameter int unsigned MaxUniqIds  = 0,
  // Maximum write transactions
  parameter int unsigned MaxWrTxns   = 0,
  // Counter width 
  parameter int unsigned CntWidth    = 0,
  // Counter width for small counters
  parameter int unsigned HsCntWidth = 0,
  // Prescaler division value 
  parameter int unsigned PrescalerDiv = 0,
  // AXI request type
  parameter type req_t = logic,
  // AXI response type
  parameter type rsp_t = logic,
  // ID type
  parameter type id_t  = logic,
  // Write address channel type
  parameter type aw_chan_t = logic,
  // Regbus type
  parameter type reg2hw_t = logic,
  parameter type hw2reg_t = logic
)(
  input  logic       clk_i,
  input  logic       rst_ni,
  // Write enqueue
  input  logic       wr_en_i,
  // Request from master
  input  req_t       mst_req_i,
  // Response from slave
  input  rsp_t       slv_rsp_i,
  // Reset request 
  output logic       reset_req_o,
  // Interrupt line
  output logic       irq_o,
  // Reset state
  input  logic       reset_clear_i,
  // Register bus
  input  reg2hw_t    reg2hw_i,
  output hw2reg_t    hw2reg_o,
  output logic       oup_ht_popped,
  output logic       timeout,
  output logic       oup_req 
);

  assign hw2reg_o.irq.unwanted_wr_resp.de = 1'b1;
  assign hw2reg_o.irq.irq.de = 1'b1;
  assign hw2reg_o.irq.w0.de = 1'b1;
  assign hw2reg_o.irq.w1.de = 1'b1;
  assign hw2reg_o.irq.w2.de = 1'b1;
  assign hw2reg_o.irq.w3.de = 1'b1;
  assign hw2reg_o.irq.w4.de = 1'b1;
  assign hw2reg_o.irq.w5.de = 1'b1;
  assign hw2reg_o.irq_addr.de = 1'b1;
  assign hw2reg_o.irq.txn_id.de = 1'b1;
  assign hw2reg_o.reset.de = 1'b1; 
  assign hw2reg_o.latency_awvld_awrdy.de = 1'b1;
  assign hw2reg_o.latency_awvld_wfirst.de = 1'b1;
  assign hw2reg_o.latency_wvld_wrdy.de = 1'b1; 
  assign hw2reg_o.latency_wvld_wlast.de = 1'b1;
  assign hw2reg_o.latency_wlast_bvld.de = 1'b1;
  assign hw2reg_o.latency_bvld_brdy.de = 1'b1;
  
  // Counter type based on used-defined counter width
  //typedef logic [CntWidth-1:0] cnt_t;
  typedef logic [HsCntWidth-1:0] hs_cnt_t;

  // Unit Budget time from aw_valid to aw_ready
  hs_cnt_t  budget_awvld_awrdy;
  // Unit Budget time from aw_valid to w_valid (w_first)
  hs_cnt_t  budget_awvld_wvld;
  // Unit Budget time from w_valid to w_ready (of w_first)
  hs_cnt_t  budget_wvld_wrdy;
  // Unit Budget time from w_valid to w_last (w_first to w_last)
  hs_cnt_t  budget_wvld_wlast;
  // Unit Budget time from w_last to b_valid
  hs_cnt_t  budget_wlast_bvld;
  // Unit Budget time from w_last to b_ready
  hs_cnt_t  budget_bvld_brdy;

  assign budget_awvld_awrdy = reg2hw_i.budget_awvld_awrdy.q;
  assign budget_awvld_wvld  = reg2hw_i.budget_unit_w.q;
  assign budget_wvld_wrdy   = reg2hw_i.budget_wvld_wrdy.q;
  assign budget_wvld_wlast  = reg2hw_i.budget_unit_w.q;
  assign budget_wlast_bvld  = reg2hw_i.budget_wlast_bvld.q;
  assign budget_bvld_brdy   = reg2hw_i.budget_bvld_brdy.q;

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
  
  // Transaction counter type def
  typedef struct packed {
    // AWVALID to AWREADY
    hs_cnt_t cnt_awvalid_awready; 
    // AWVALID to WFIRST
    logic [13:0] cnt_awvalid_wfirst; 
    // WVALID to WREADY of WFIRST 
    hs_cnt_t cnt_wvalid_wready_first; 
    // WFIRST to WLAST
    logic [13:0] cnt_wfirst_wlast;  
    // WLAST to BVALID  
    hs_cnt_t cnt_wlast_bvalid;  
    // WLAST to BREADY  
    hs_cnt_t cnt_bvalid_bready;   
  } write_cnters_t;

  // FSM per each transaction
  typedef enum logic [1:0] {
    IDLE,// for idle LD entries retired from aw-w-b lifecycle
    WRITE_ADDRESS,
    WRITE_DATA,
    WRITE_RESPONSE
  } write_state_t;

  // LD entry for each txn
  typedef struct packed {
    // Txn meta info, put AW channel info  
    aw_chan_t       metadata;
    // AW, W, B or IDLE(after dequeue)
    write_state_t   write_state;
    // Six counters per each write txn
    write_cnters_t  counters; 
    // W1 and w3 are dynamic budget determined by unit_budget given in sw and accum length in hw
    // AW_VALID to W_VALID (W_FIRST)
    logic [13:0]    w1_budget; 
    // W_VALID to W_LAST (W_FIRST to W_LAST)
    logic [13:0]    w3_budget;
    // Response ID matches request ID?
    logic           found_match;
    // Next pointer in LD table
    ld_idx_t        next;
    // Is this LD entry occupied by any txn?
    logic           free;
  } linked_data_t;

  // W fifo
  localparam int unsigned PtrWidth = $clog2(MaxWrTxns);
  // FIFO storage for transaction indices 
  logic [LdIdxWidth-1:0] w_fifo [MaxWrTxns]; 
  // Write and read pointers
  logic [PtrWidth-1:0] wr_ptr_d, wr_ptr_q, rd_ptr_d, rd_ptr_q;
  // Status signals
  logic fifo_full_d, fifo_full_q, fifo_empty_d, fifo_empty_q; 
 
  // Head tail table entry 
  head_tail_t [HtCapacity-1:0]    head_tail_d,    head_tail_q;
    
  // Array of linked data
  linked_data_t [MaxWrTxns-1:0]   linked_data_d,  linked_data_q;

  logic                           inp_gnt,
                                  full,
                                  match_in_id_valid,
                                  match_out_id_valid,
                                  no_in_id_match,
                                  no_out_id_match;

  logic [HtCapacity-1:0]          head_tail_free,
                                  idx_matches_in_id,
                                  idx_matches_out_id,
                                  idx_rsp_id;

  logic [MaxWrTxns-1:0]           linked_data_free;
 
  id_t                            match_in_id, match_out_id, oup_id;

  ht_idx_t                        head_tail_free_idx,
                                  match_in_idx,
                                  match_out_idx,
                                  rsp_idx;

  ld_idx_t                        linked_data_free_idx,
                                  oup_data_free_idx,
                                  active_idx;

  logic                           oup_data_valid,                           
                                  oup_data_popped;
                                 // oup_ht_popped;
  
  logic                           reset_req, reset_req_q,                        
                                  id_exists,
                                
                                  irq;

  logic [13:0]                    awvld_wfirst_budget,
                                  wfirst_wlast_budget;

  // Find the index in the head-tail table that matches a given ID.
  for (genvar i = 0; i < HtCapacity; i++) begin: gen_idx_match
    assign idx_matches_in_id[i] = match_in_id_valid && (head_tail_q[i].id == match_in_id) && !head_tail_q[i].free;
    assign idx_matches_out_id[i] = match_out_id_valid && (head_tail_q[i].id == match_out_id) && !head_tail_q[i].free;
    assign idx_rsp_id[i] = (head_tail_q[i].id == slv_rsp_i.b.id) && !head_tail_q[i].free;
  end
    
  assign no_in_id_match = !(|idx_matches_in_id);
  assign no_out_id_match = !(|idx_matches_out_id);
  assign id_exists =  (|idx_rsp_id);
  assign irq_o = irq;

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
  onehot_to_bin #(
    .ONEHOT_WIDTH ( HtCapacity )
  ) i_id_ohb_rsp (
    .onehot ( idx_rsp_id    ),
    .bin    ( rsp_idx       )
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
  
  // Data can be accepted if the linked list pool is not full, or some da  ta is simultaneously.
  assign inp_gnt = ~full || oup_data_popped;
  assign active_idx = w_fifo[rd_ptr_q];

  // To calculate the total burst lengths of all txns prior at time of request acceptance
  logic [CntWidth-1:0] accum_burst_length;
  always_comb begin: proc_accum_length
    accum_burst_length = 0;
    for (int i = 0; i < MaxWrTxns; i++) begin
      if (!linked_data_q[i].free) begin
        accum_burst_length += ( linked_data_q[i].metadata.len + 1 );
      end
    end
  end
  
  logic prescaled_en;
  prescaler #(
    .DivFactor(PrescalerDiv)
    )i_wr_prescaler(
    .clk_i( clk_i),
    .rst_ni( rst_ni),
    .prescaled_o( prescaled_en)
  ); 

  logic aw_valid_sticky, aw_ready_sticky;
  logic w_valid_sticky, w_ready_sticky, w_last_sticky;
  logic b_valid_sticky, b_ready_sticky;

  sticky_bit i_awvalid_sticky (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .release_i(prescaled_en),
    .sticky_i(mst_req_i.aw_valid),
    .sticky_o(aw_valid_sticky)
  );

  sticky_bit i_awready_sticky (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .release_i(prescaled_en),
    .sticky_i(slv_rsp_i.aw_ready),
    .sticky_o(aw_ready_sticky)
  );

  sticky_bit i_wvalid_sticky (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .release_i(prescaled_en),
    .sticky_i(mst_req_i.w_valid),
    .sticky_o(w_valid_sticky)
  );

  sticky_bit i_wready_sticky (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .release_i(prescaled_en),
    .sticky_i(slv_rsp_i.w_ready),
    .sticky_o(w_ready_sticky)
  );

  sticky_bit i_wlast_sticky (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .release_i(prescaled_en),
    .sticky_i(mst_req_i.w.last),
    .sticky_o(w_last_sticky)
  );

  sticky_bit i_bvalid_sticky (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .release_i(prescaled_en),
    .sticky_i(slv_rsp_i.b_valid),
    .sticky_o(b_valid_sticky)
  );

  sticky_bit i_bready_sticky (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .release_i(prescaled_en),
    .sticky_i(mst_req_i.b_ready),
    .sticky_o(b_ready_sticky)
  );

  always_comb begin : proc_wr_queue
    match_in_id         = '0;
    match_out_id        = '0;
    match_in_id_valid   = 1'b0;
    match_out_id_valid  = 1'b0;
    head_tail_d         = head_tail_q;
    linked_data_d       = linked_data_q;
    oup_data_valid      = 1'b0;
    oup_data_popped     = 1'b0;
    oup_ht_popped       = 1'b0;
    oup_req             = 1'b0;
    oup_id              = '0;
    irq                 = '0; 
    timeout             = '0;
    reset_req           = reset_req_q;
    wr_ptr_d            = wr_ptr_q;
    rd_ptr_d            = rd_ptr_q;
    fifo_full_d         = fifo_full_q;
    fifo_empty_d        = fifo_empty_q;
    hw2reg_o.latency_awvld_awrdy.d  = reg2hw_i.latency_awvld_awrdy.q;
    hw2reg_o.latency_awvld_wfirst.d = reg2hw_i.latency_awvld_wfirst.q;
    hw2reg_o.latency_wlast_bvld.d   = reg2hw_i.latency_wlast_bvld.q;
    hw2reg_o.latency_bvld_brdy.d    = reg2hw_i.latency_bvld_brdy.q;
    hw2reg_o.latency_awvld_awrdy.d  = reg2hw_i.latency_awvld_awrdy.q;
    hw2reg_o.latency_awvld_wfirst.d = reg2hw_i.latency_awvld_wfirst.q;
    hw2reg_o.irq.w0.d               = reg2hw_i.irq.w0.q;
    hw2reg_o.irq.w1.d               = reg2hw_i.irq.w1.q;
    hw2reg_o.irq.w2.d               = reg2hw_i.irq.w2.q;
    hw2reg_o.irq.w3.d               = reg2hw_i.irq.w3.q;
    hw2reg_o.irq.w4.d               = reg2hw_i.irq.w4.q;
    hw2reg_o.irq.w5.d               = reg2hw_i.irq.w5.q;
    hw2reg_o.irq.txn_id.d           = reg2hw_i.irq.txn_id.q;
    hw2reg_o.irq_addr.d             = reg2hw_i.irq_addr.q;
    hw2reg_o.irq.irq.d              = reg2hw_i.irq.irq.q;
    hw2reg_o.reset.d                = reg2hw_i.reset.q; 
    hw2reg_o.irq.unwanted_wr_resp.d     = reg2hw_i.irq.unwanted_wr_resp.q;

    // Transaction states handling
    // remove stick signals from states handling
    for ( int i = 0; i < MaxWrTxns; i++ ) begin : proc_wr_txn_states
      if (!linked_data_q[i].free) begin 
        case ( linked_data_q[i].write_state )
          WRITE_ADDRESS: begin
            if (linked_data_q[i].counters.cnt_awvalid_awready > budget_awvld_awrdy) begin
              timeout = 1'b1;
              reset_req = 1'b1;
              hw2reg_o.reset.d = 1'b1;
              hw2reg_o.irq.w0.d = 1'b1;
            end 
            if( linked_data_q[i].counters.cnt_awvalid_wfirst >  linked_data_q[i].w1_budget) begin
              timeout = 1'b1;
              hw2reg_o.irq.w1.d = 1'b1;      
            end
            // to enter write_data state, last txn has done one w channel
            // w_valid comes and next active transaction on w channel points to current one
            if ( mst_req_i.w_valid && !timeout && !fifo_empty_q && (active_idx == i)) begin
              hw2reg_o.latency_awvld_awrdy.d = linked_data_q[i].counters.cnt_awvalid_awready;
              hw2reg_o.latency_awvld_wfirst.d = linked_data_q[i].w1_budget - linked_data_q[i].counters.cnt_awvalid_wfirst;
              linked_data_d[i].write_state = WRITE_DATA;
            end 
            // single transfer transaction where w_valid and w_last are shown at the same cycle
            if ( ( mst_req_i.w_valid && mst_req_i.w.last ) && !timeout && !fifo_empty_q && (active_idx == i)) begin
              hw2reg_o.latency_awvld_awrdy.d = linked_data_q[i].counters.cnt_awvalid_awready;
              hw2reg_o.latency_awvld_wfirst.d = linked_data_q[i].w1_budget - linked_data_q[i].counters.cnt_awvalid_wfirst;
              linked_data_d[i].write_state = WRITE_DATA;
            end 
          end

          WRITE_DATA: begin
            if (linked_data_q[i].counters.cnt_wvalid_wready_first > budget_wvld_wrdy) begin
              timeout = 1'b1;
              reset_req = 1'b1;
              hw2reg_o.reset.d = 1'b1;
              hw2reg_o.irq.w2.d = 1'b1;
            end 
            if (linked_data_q[i].counters.cnt_wfirst_wlast > linked_data_q[i].w3_budget) begin
              timeout = 1'b1;
              hw2reg_o.irq.w3.d = 1'b1;
            end                                                                                                                        
            if ( mst_req_i.w.last && !timeout ) begin
              hw2reg_o.latency_wvld_wrdy.d = linked_data_q[i].counters.cnt_wvalid_wready_first;
              hw2reg_o.latency_wvld_wlast.d = linked_data_q[i].w3_budget - linked_data_q[i].counters.cnt_wfirst_wlast;
              linked_data_d[i].write_state = WRITE_RESPONSE;
              rd_ptr_d = (rd_ptr_q + 1)% MaxWrTxns;  // Update read pointer after last W data
              fifo_empty_d = (rd_ptr_q == wr_ptr_q); 
            end
          end

          WRITE_RESPONSE: begin
            if ( linked_data_q[i].counters.cnt_wlast_bvalid > budget_wlast_bvld ) begin
              timeout = 1'b1;
              reset_req = 1'b1;
              hw2reg_o.reset.d = 1'b1;
              hw2reg_o.irq.w4.d = 1'b1;
            end
            if ( linked_data_q[i].counters.cnt_bvalid_bready > budget_bvld_brdy) begin
              timeout = 1'b1;
              hw2reg_o.irq.w5.d = 1'b1;
            end
            // handshake, id match and no timeout, successul completion
            // Check for the valid and readhy handshake
            if ( mst_req_i.b_ready && slv_rsp_i.b_valid && !timeout ) begin 
              if ( id_exists ) begin 
                // if IDs match, successful completion. dequeue request and mark the match as found
                // also make sure it is the first txn of the same id
                linked_data_d[i].found_match = ((linked_data_q[i].metadata.id == slv_rsp_i.b.id) && (head_tail_q[rsp_idx].head == i) )? 1'b1 : 1'b0;
              end else begin
                reset_req = 1'b1;
                hw2reg_o.reset.d = 1'b1;
                hw2reg_o.irq.unwanted_wr_resp.d = 'b1;
              end 
            end 
            if ( linked_data_q[i].found_match) begin
              oup_req = 1; 
              oup_id = linked_data_q[i].metadata.id;
              //$display("found match! oup_req = %0d, oup_id = %0d", oup_req, oup_id);
              hw2reg_o.latency_wlast_bvld.d = linked_data_q[i].counters.cnt_wlast_bvalid;
              hw2reg_o.latency_bvld_brdy.d = linked_data_q[i].counters.cnt_bvalid_bready;
              linked_data_d[i]          = '0;
              linked_data_d[i].counters     = '0;
              linked_data_d[i].write_state     = IDLE;
              linked_data_d[i].free     = 1'b1;
            end
          end

          default:
            linked_data_d[i].write_state = IDLE;
        endcase
        // timeout and reset_req do not necessarily happen at the same time
        // but we need to abort all txns if any of them happens
        if (timeout || reset_req) begin
          // Specific handling for reset_req
          for (int i = 0; i < MaxWrTxns; i++ ) begin
            linked_data_d[i]          = '0;
            linked_data_d[i].counters     = '0;
            linked_data_d[i].write_state     = IDLE;
            linked_data_d[i].free     = 1'b1;
            oup_req = 1;
            oup_id = linked_data_q[i].metadata.id;
            irq = 1'b1;
          end
        end  
      end
    end
    
    // Dequeue 
    if (oup_req) begin : proc_txn_dequeue
      match_out_id = oup_id;
      match_out_id_valid = 1'b1;
      if (!no_out_id_match) begin
        oup_data_valid = 1'b1;
        oup_data_popped = 1;
        // Set free bit of linked data entry, all other bits are don't care.
        linked_data_d[head_tail_q[match_out_idx].head]          = '0;
        linked_data_d[head_tail_q[match_out_idx].head].counters     = '0;
        linked_data_d[head_tail_q[match_out_idx].head].write_state     = IDLE;
        linked_data_d[head_tail_q[match_out_idx].head].free     = 1'b1;
        //$display("found match 3 valuel %d",linked_data_d[head_tail_q[match_out_idx].head].found_match );
        // If it is the last cell of this ID
        if (head_tail_q[match_out_idx].head == head_tail_q[match_out_idx].tail) begin
          oup_ht_popped = 1'b1;
          head_tail_d[match_out_idx] = '{free: 1'b1, default: '0};
        end else begin
          head_tail_d[match_out_idx].head = linked_data_q[head_tail_q[match_out_idx].head].next;
        end
      end 
    end
    
    // Transaction enqueue into LD table
    if (wr_en_i && inp_gnt ) begin : proc_txn_enqueue
      match_in_id = mst_req_i.aw.id;
      match_in_id_valid = 1'b1;
      awvld_wfirst_budget = budget_awvld_wvld * ( accum_burst_length + mst_req_i.aw.len + 1); // to-do: if not the first txn in ld, use w_fifo
      wfirst_wlast_budget = budget_wvld_wlast * ( mst_req_i.aw.len + 1 );
      // If output data was popped for this ID, which lead the head_tail to be popped,
      // then repopulate this head_tail immediately.
      // When an AW request is accepted, index it into the FIFO. 
      // This index refers to the slot in the linked data table where the transaction details are stored.
      if (mst_req_i.aw_valid && !fifo_full_q) begin: proc_w_fifo
        w_fifo[wr_ptr_d] = oup_data_popped ? oup_data_free_idx : linked_data_free_idx;
        wr_ptr_d = (wr_ptr_q + 1) % MaxWrTxns;//circular buffer
        fifo_empty_d = 0;
        fifo_full_d = (rd_ptr_q == (wr_ptr_q + 1) % MaxWrTxns);
      end
      if (oup_ht_popped && (oup_id == mst_req_i.aw.id)) begin
        head_tail_d[match_out_idx] = '{
          id: mst_req_i.aw.id,
          head: oup_data_free_idx,
          tail: oup_data_free_idx,
          free: 1'b0
        };
        linked_data_d[oup_data_free_idx] = '{
          metadata: mst_req_i.aw,
          write_state: WRITE_ADDRESS,
          counters: 0,
          w1_budget: awvld_wfirst_budget,
          w3_budget: wfirst_wlast_budget,
          found_match: 0,
          next: '0,
          free: 1'b0
        };
      end  else if (no_in_id_match) begin
        // Else, if no head_tail corresponds to the input id, and no same ID just popped.
        // reuse any freed up entry
        if (oup_ht_popped) begin
          head_tail_d[match_out_idx] = '{
            id: mst_req_i.aw.id,
            head: oup_data_free_idx,
            tail: oup_data_free_idx,
            free: 1'b0
          };
          linked_data_d[oup_data_free_idx] = '{
            metadata: mst_req_i.aw,
            write_state: WRITE_ADDRESS,
            counters: 0,
            w1_budget: awvld_wfirst_budget,
            w3_budget: wfirst_wlast_budget,
            found_match: 0,
            next: '0,
            free: 1'b0
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
              write_state: WRITE_ADDRESS,
              counters: 0,
              w1_budget: awvld_wfirst_budget,
              w3_budget: wfirst_wlast_budget,
              found_match: 0,
              next: '0,
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
              write_state: WRITE_ADDRESS,
              counters: 0,
              w1_budget: awvld_wfirst_budget,
              w3_budget: wfirst_wlast_budget,
              found_match: 0,
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
            metadata: mst_req_i.aw,
            write_state: WRITE_ADDRESS,
            counters: 0,
            w1_budget: awvld_wfirst_budget,
            w3_budget: wfirst_wlast_budget,
            found_match: 0,
            next: '0,
            free: 1'b0
          };
        end else begin
          linked_data_d[head_tail_q[match_in_idx].tail].next = linked_data_free_idx;
          head_tail_d[match_in_idx].tail = linked_data_free_idx;
          linked_data_d[linked_data_free_idx] = '{
            metadata: mst_req_i.aw,
            write_state: WRITE_ADDRESS,
            counters: 0,
            w1_budget: awvld_wfirst_budget,
            w3_budget: wfirst_wlast_budget,
            found_match: 0,
            next: '0,
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

  for (genvar i = 0; i < MaxWrTxns; i++) begin: gen_wr_counter
    /// state transitions and counter updates
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        linked_data_q[i] <= '0;
        // mark all slots as free
        linked_data_q[i][0] <= 1'b1;
      end else begin
        linked_data_q[i]  <= linked_data_d[i]; 
        // only if this slot is in use, that is to say there is an outstanding transaction
        if (!linked_data_q[i].free) begin
          case (linked_data_q[i].write_state)
            WRITE_ADDRESS: begin
              // Counter 0: AW Phase - AW_VALID to AW_READY, handshake is checked meanwhile
              if (!aw_ready_sticky && prescaled_en)
                linked_data_q[i].counters.cnt_awvalid_awready <= linked_data_q[i].counters.cnt_awvalid_awready + 1 ; // note: cannot do self-increment
              // Counter 1: AW Phase - AW_VALID to W_VALID (first data)
             // if (!mst_req_i.w_valid) 
              if ( prescaled_en)
                linked_data_q[i].counters.cnt_awvalid_wfirst <= linked_data_q[i].counters.cnt_awvalid_wfirst + 1;
            end

            WRITE_DATA: begin
              // Counter 2: W Phase - W_VALID to W_READY (first data), handshake of first data is checked
              if (w_valid_sticky && !w_ready_sticky && prescaled_en ) 
                linked_data_q[i].counters.cnt_wvalid_wready_first  <= linked_data_q[i].counters.cnt_wvalid_wready_first + 1;
              // Counter 3: W Phase - W_VALID(W_FIRST) to W_LAST 
              //if (!mst_req_i.w.last)
              if ( prescaled_en )
                linked_data_q[i].counters.cnt_wfirst_wlast  <= linked_data_q[i].counters.cnt_wfirst_wlast + 1;
            end

            WRITE_RESPONSE: begin
              // B_valid comes the cycle after w_last. 
              // Counter 4: B Phase - W_LAST to B_VALID
              if(b_valid_sticky && prescaled_en )
                linked_data_q[i].counters.cnt_wlast_bvalid <= linked_data_q[i].counters.cnt_wlast_bvalid + 1;
              // Counter 5: B Phase - B_VALID to B_READY, handshake is checked, stop counting upon handshake
              if(b_valid_sticky && !b_ready_sticky && prescaled_en )
                linked_data_q[i].counters.cnt_bvalid_bready <= linked_data_q[i].counters.cnt_bvalid_bready +1;
            end 
          endcase // linked_data_q[i].write_state
        end
      end
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      reset_req_q <= 1'b0;
      wr_ptr_q <= '0;
      rd_ptr_q <= '0;
      fifo_full_q <= '0;
      fifo_empty_q <= '0;
    end else begin
      wr_ptr_q <= wr_ptr_d;
      rd_ptr_q <= rd_ptr_d;
      fifo_empty_q <= fifo_empty_d;
      fifo_full_q <= fifo_full_d;
      if (reset_req) begin
        reset_req_q <= reset_req;
      end else if (reset_clear_i) begin
        reset_req_q <= 1'b0;
      end
    end
  end

  assign   reset_req_o = reset_req_q;

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

