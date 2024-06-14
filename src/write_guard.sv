
module write_guard #(
  // Maximum number of unique IDs
  parameter int unsigned MaxUniqIds  = 0,
  // Maximum write transactions
  parameter int unsigned MaxWrTxns   = 0,
  // Counter width 
  parameter int unsigned CntWidth    = 0,
  // AXI request type
  parameter type req_t = logic,
  // AXI response type
  parameter type rsp_t = logic,
  // ID type
  parameter type id_t  = logic,
  // Write address channel type
  parameter type aw_chan_t = logic,
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
  // Slave request request 
  output logic       reset_req_o,
  output logic       irq_o,
  input  logic       reset_clear_i,
  // Register bus
  input  reg2hw_t    reg2hw_i,
  output hw2reg_t    hw2reg_o
);

  assign hw2reg_o.irq.mis_id_wr.de = 1'b1;
  assign hw2reg_o.irq.unwanted_txn.de = 1'b1;
  assign hw2reg_o.irq.w0.de = 1'b1;
  assign hw2reg_o.irq.w1.de = 1'b1;
  assign hw2reg_o.irq.w2.de = 1'b1;
  assign hw2reg_o.irq.w3.de = 1'b1;
  assign hw2reg_o.irq.w4.de = 1'b1;
  assign hw2reg_o.irq.w5.de = 1'b1;
  assign hw2reg_o.irq_addr.de = 1'b1;
  assign hw2reg_o.reset.de = 1'b1; 
  assign hw2reg_o.latency_awvld_awrdy.de = 1'b1;
  assign hw2reg_o.latency_awvld_wfirst.de = 1'b1;
  assign hw2reg_o.latency_wvld_wrdy.de = 1'b1; 
  assign hw2reg_o.latency_wvld_wlast.de = 1'b1;
  assign hw2reg_o.latency_wlast_bvld.de = 1'b1;
  assign hw2reg_o.latency_wlast_brdy.de = 1'b1;
  
  typedef logic [CntWidth-1:0] cnt_t;

  // Budget time from aw_valid to aw_ready
  cnt_t  budget_awvld_awrdy;
  // Budget time from aw_valid to w_valid
  cnt_t  budget_awvld_wvld;
  // Budget time from w_valid to w_ready
  cnt_t  budget_wvld_wrdy;
  // Budget time from w_valid to w_last
  cnt_t  budget_wvld_wlast;
  // Budget time from w_last to b_valid
  cnt_t  budget_wlast_bvld;
  // Budget time from w_last to b_ready
  cnt_t  budget_wlast_brdy;

  assign budget_awvld_awrdy = reg2hw_i.budget_awvld_awrdy.q;
  assign budget_awvld_wvld  = reg2hw_i.budget_awvld_wfirst.q;
  assign budget_wvld_wrdy   = reg2hw_i.budget_wvld_wrdy.q;
  assign budget_wvld_wlast  = reg2hw_i.budget_wvld_wlast.q;
  assign budget_wlast_bvld  = reg2hw_i.budget_wlast_bvld.q;
  assign budget_wlast_brdy  = reg2hw_i.budget_wlast_brdy.q;

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
    logic [CntWidth -1:0] cnt_awvalid_awready; 
    // AWVALID to WFIRST
    logic [CntWidth -1:0] cnt_awvalid_wfirst; 
    // WVALID to WREADY of WFIRST 
    logic [CntWidth -1:0] cnt_wvalid_wready_first; 
    // WFIRST to WLAST
    logic [CntWidth -1:0] cnt_wfirst_wlast;  
    // WLAST to BVALID  
    logic [CntWidth -1:0] cnt_wlast_bvalid;  
    // WLAST to BREADY  
    logic [CntWidth  -1:0] cnt_wlast_bready;   
  } write_cnters_t;

  // FSM state of each transaction
  typedef enum logic [1:0] {
    IDLE,
    WRITE_ADDRESS,
    WRITE_DATA,
    WRITE_RESPONSE
  } write_state_t;

  // Type of an entry in the linked data table.
  typedef struct packed {
    aw_chan_t       metadata;
    logic           timeout;
    write_state_t   write_state;
    write_cnters_t  counters; 
    cnt_t           w1_budget;
    cnt_t           w3_budget;
    logic           found_match;
    ld_idx_t        next;
    logic           free;
  } linked_data_t;
  
  // Head tail table entry 
  head_tail_t [HtCapacity-1:0]    head_tail_d,    head_tail_q;
    
  // Array of linked data
  linked_data_t [MaxWrTxns-1:0]   linked_data_d,  linked_data_q;

  logic                           inp_gnt,
                                  oup_gnt,
                                  full,
                                  match_in_id_valid,
                                  match_out_id_valid,
                                  no_in_id_match,
                                  no_out_id_match;

  logic [HtCapacity-1:0]          head_tail_free,
                                  idx_matches_in_id,
                                  idx_matches_out_id,
                                  idx_rsp_id;

  logic [MaxWrTxns-1:0]           linked_data_free,
                                  rsp_id_exists;
 
  id_t                            match_in_id, match_out_id, oup_id;

  ht_idx_t                        head_tail_free_idx,
                                  match_in_idx,
                                  match_out_idx,
                                  rsp_idx;

  ld_idx_t                        linked_data_free_idx,
                                  oup_data_free_idx;

  logic                           oup_data_valid,                           
                                  oup_data_popped,
                                  oup_ht_popped;
  
  logic                           reset_req, reset_req_q,
                                  irq, irq_q,                        
                                  id_exists,
                                  oup_req;

  cnt_t                           awvld_wfirst_budget,
                                  wfirst_wlast_budget;

  // Find the index in the head-tail table that matches a given ID.
  for (genvar i = 0; i < HtCapacity; i++) begin: gen_idx_match
    assign idx_matches_in_id[i] = match_in_id_valid && (head_tail_q[i].id == match_in_id) && !head_tail_q[i].free;
    assign idx_matches_out_id[i] = match_out_id_valid && (head_tail_q[i].id == match_out_id) && !head_tail_q[i].free;
    assign idx_rsp_id[i] = (head_tail_q[i].id == slv_rsp_i.b.id) && !head_tail_q[i].free;
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

  // more efficient to transverswe HT instead of LD
  // Find Response ID exists or not to identidy unwanted txn
  for (genvar i = 0; i < HtCapacity; i++) begin: gen_rsp_id_exists
    assign rsp_id_exists[i] = (head_tail_q[i].id == slv_rsp_i.b.id) && !head_tail_q[i].free;
  end
  assign id_exists =  (|rsp_id_exists);

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

  // To calculate the total burst lengths.
  logic [CntWidth-1:0] accum_burst_length;

  always_comb begin: proc_accum_length
    accum_burst_length = 0;
    for (int i = 0; i < MaxWrTxns; i++) begin
      if (!linked_data_q[i].free) begin
        accum_burst_length += linked_data_q[i].metadata.len;
      end
    end
  end

  always_comb begin : proc_wr_queue
    match_in_id         = '0;
    match_out_id        = '0;
    match_in_id_valid   = 1'b0;
    match_out_id_valid  = 1'b0;
    head_tail_d         = head_tail_q;
    linked_data_d       = linked_data_q;
    oup_gnt             = 1'b0;
    oup_data_valid      = 1'b0;
    oup_data_popped     = 1'b0;
    oup_ht_popped       = 1'b0;
    oup_id              = 1'b0;
    oup_req             = 1'b0;
    reset_req           = 1'b0;
    irq                 = 1'b0; 
    
    if (wr_en_i && inp_gnt ) begin : proc_txn_enqueue
      match_in_id = mst_req_i.aw.id;
      match_in_id_valid = 1'b1;
      //awvld_wfirst_budget = budget_awvld_wvld * accum_burst_length; // to-do: if not the first one
      awvld_wfirst_budget = budget_awvld_wvld ; // need to change
      wfirst_wlast_budget = budget_wvld_wlast * mst_req_i.aw.len;
      // If output data was popped for this ID, which lead the head_tail to be popped,
      // then repopulate this head_tail immediately.
      if (oup_ht_popped && (oup_id == mst_req_i.aw.id)) begin
        head_tail_d[match_out_idx] = '{
          id: mst_req_i.aw.id,
          head: oup_data_free_idx,
          tail: oup_data_free_idx,
          free: 1'b0
        };
        linked_data_d[oup_data_free_idx] = '{
          metadata: mst_req_i.aw,
          timeout: 0,
          write_state: WRITE_ADDRESS,
          counters: 0,
          w1_budget: awvld_wfirst_budget,
          w3_budget: wfirst_wlast_budget,
          found_match: 0,
          next: '0,
          free: 1'b0
        };
      end else if (no_in_id_match) begin
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
            timeout: 0,
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
              timeout: 0,
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
              timeout: 0,
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
            timeout: 0,
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
            timeout: 0,
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
    // Transaction states handling
    for ( int i = 0; i < MaxWrTxns; i++ ) begin : proc_wr_txn_states
      if (!linked_data_q[i].free) begin 
        case ( linked_data_q[i].write_state )
          IDLE: begin
              linked_data_d[i]           = '0;
              linked_data_d[i].free      = 1'b1;
          end
          WRITE_ADDRESS: begin
            if ( mst_req_i.w_valid && !linked_data_q[i].timeout ) begin
              hw2reg_o.latency_awvld_awrdy.d = linked_data_q[i].counters.cnt_awvalid_awready;
              hw2reg_o.latency_awvld_wfirst.d = linked_data_q[i].w1_budget - linked_data_q[i].counters.cnt_awvalid_wfirst;
              linked_data_d[i].write_state = WRITE_DATA;
            end
            if (linked_data_q[i].counters.cnt_awvalid_awready >= budget_awvld_awrdy) begin
              linked_data_d[i].timeout = 1'b1;
              // log timeout info into regs
              hw2reg_o.irq.w0.d = 1'b1;
              hw2reg_o.irq_addr.d = linked_data_q[i].metadata.addr;
              hw2reg_o.reset.d = 1'b1; 
              // mst_rsp_o.b.resp = 2'b10; move to top
              // general reset, irq 
              reset_req = 1'b1;
              irq = 1'b1;
              // dequeue 
              oup_req  = 1;
              oup_id = linked_data_q[i].metadata.id;
              linked_data_d[i]               = '0;
              linked_data_d[i].write_state   = IDLE;
              linked_data_d[i].free          = 1'b1;
            end 
            if(linked_data_q[i].w1_budget - linked_data_q[i].counters.cnt_awvalid_wfirst <= 0 ) begin
              linked_data_d[i].timeout = 1'b1;
              hw2reg_o.irq.w1.d = 1'b1;
              hw2reg_o.irq_addr.d = linked_data_q[i].metadata.addr;
              hw2reg_o.reset.d = 1'b1;
              reset_req = 1'b1;
              irq = 1'b1;
              oup_req  = 1;
              oup_id = linked_data_q[i].metadata.id; 
              linked_data_d[i]               = '0;
              linked_data_d[i].write_state   = IDLE;
              linked_data_d[i].free          = 1'b1;
            end
          end
          WRITE_DATA: begin
            if ( mst_req_i.w.last && !linked_data_q[i].timeout ) begin
              hw2reg_o.latency_wvld_wrdy.d = linked_data_q[i].counters.cnt_wvalid_wready_first;
              hw2reg_o.latency_wvld_wlast.d = linked_data_q[i].w3_budget - linked_data_q[i].counters.cnt_wfirst_wlast;
              linked_data_d[i].write_state = WRITE_RESPONSE;
            end
            if (linked_data_q[i].counters.cnt_wvalid_wready_first >= budget_wvld_wrdy) begin
              linked_data_d[i].timeout = 1'b1;
              hw2reg_o.irq.w2.d = 1'b1;
              hw2reg_o.irq_addr.d = linked_data_q[i].metadata.addr;
              hw2reg_o.reset.d = 1'b1;
              //mst_rsp_o.b.resp = 2'b10; move to top
              reset_req = 1'b1;
              irq = 1'b1;
              oup_req  = 1;
              oup_id = linked_data_q[i].metadata.id;
              linked_data_d[i]               = '0;
              linked_data_d[i].write_state   = IDLE;
              linked_data_d[i].free          = 1'b1; 
            end 
            if (linked_data_q[i].w3_budget - linked_data_q[i].counters.cnt_wfirst_wlast <= 0) begin
              linked_data_d[i].timeout = 1'b1;
              hw2reg_o.irq.w3.d = 1'b1;
              hw2reg_o.irq_addr.d = linked_data_q[i].metadata.addr;
              hw2reg_o.reset.d = 1'b1;
              reset_req = 1'b1;
              irq = 1'b1;
              oup_req  = 1;
              oup_id = linked_data_q[i].metadata.id;
              linked_data_d[i]               = '0;
              linked_data_d[i].write_state   = IDLE;
              linked_data_d[i].free          = 1'b1;  
            end
          end
          // Timeout check, also handle txn dequeue in both faulty and fault-free case, plus id check
          // ID check if HS is validated AND no timeout
          // so, we first start with HS check when there is no timeout detected
          // if that is a yes, do ID check. if no, HS violation. write to different cause registers,
          // but in case of ID mismatch, as out of order completion is allowed in axi4(a generous budget might benefit?).
          // but in case of mismatch, we cannot dequeue it immediately,
          // first check if it is in ht, if yes, keep checking til there is a match as long as no timeout. if not in ht, report unwanted txn.
          WRITE_RESPONSE: begin
            if ( linked_data_q[i].counters.cnt_wlast_bvalid >= budget_wlast_bvld ) begin
              linked_data_d[i].timeout = 1'b1;
              hw2reg_o.irq.w4.d = 1'b1;
              hw2reg_o.irq_addr.d = linked_data_q[i].metadata.addr;
              hw2reg_o.reset.d = 1'b1;
             // mst_rsp_o.b.resp = 2'b10;
              reset_req = 1'b1;
              irq = 1'b1;
              oup_req  = 1;
              oup_id = linked_data_q[i].metadata.id;  
              linked_data_d[i]               = '0;
              linked_data_d[i].write_state   = IDLE;
              linked_data_d[i].free          = 1'b1;
            end
            if ( linked_data_q[i].counters.cnt_wlast_bready >= budget_wlast_brdy) begin
              linked_data_d[i].timeout = 1'b1;
              hw2reg_o.irq.w5.d = 1'b1;
              hw2reg_o.irq_addr.d = linked_data_q[i].metadata.addr;
              hw2reg_o.reset.d = 1'b1;
              reset_req = 1'b1;
              irq = 1'b1;
              oup_req  = 1;
              oup_id = linked_data_q[i].metadata.id;
              linked_data_d[i]               = '0;
              linked_data_d[i].write_state   = IDLE;
              linked_data_d[i].free          = 1'b1;
            end
            // handshake, id match and no timeout, successul completion
            // Check for the valid and readhy handshake
            if ( mst_req_i.b_ready && slv_rsp_i.b_valid && !linked_data_d[i].timeout ) begin 
              if ( id_exists ) begin 
                // if IDs match, successful completion. dequeue request and mark the match as found
                if ( !linked_data_q[i].found_match) begin
                  linked_data_d[i].found_match = ((linked_data_q[i].metadata.id == slv_rsp_i.b.id) && (head_tail_q[rsp_idx].head == i) )? 1'b1 : 1'b0;
                end else begin
                  // successful 
                  oup_req = 1; 
                  oup_id = linked_data_q[i].metadata.id;
                  linked_data_d[i]               = '0;
                  linked_data_d[i].write_state   = IDLE;
                  linked_data_d[i].free          = 1'b1;
                  hw2reg_o.latency_wlast_bvld.d = linked_data_q[i].counters.cnt_wlast_bvalid;
                  hw2reg_o.latency_wlast_brdy.d = linked_data_q[i].counters.cnt_wlast_bready;
                end 
              end else begin 
                hw2reg_o.irq.unwanted_txn.d = 1'b1;
                hw2reg_o.reset.d = 1'b1;
                //mst_rsp_o.b.resp = 2'b10;
                reset_req = 1'b1;
                irq = 1'b1;
              end 
            end else begin 
              if( linked_data_d[i].timeout ) begin
                // If there's a timeout, still no match found
                hw2reg_o.irq_addr.d = linked_data_q[i].metadata.addr;
                hw2reg_o.reset.d = 1'b1;
               // mst_rsp_o.b.resp = 2'b10;
                reset_req = 1'b1;
                irq = 1'b1;
                oup_req  = 1;
                oup_id = linked_data_q[i].metadata.id;
                linked_data_d[i]               = '0;
                linked_data_d[i].write_state   = IDLE;
                linked_data_d[i].free          = 1'b1;
              end
            end
          end
        endcase 
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
        linked_data_d[head_tail_q[match_out_idx].head].write_state     = IDLE;
        linked_data_d[head_tail_q[match_out_idx].head].free     = 1'b1;
        // If it is the last cell of this ID
        if (head_tail_q[match_out_idx].head == head_tail_q[match_out_idx].tail) begin
          oup_ht_popped = 1'b1;
          head_tail_d[match_out_idx] = '{free: 1'b1, default: '0};
        end else begin
          head_tail_d[match_out_idx].head = linked_data_q[head_tail_q[match_out_idx].head].next;
        end
      end 
      // Always grant the output request.
      oup_gnt = 1'b1;
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
        if (wr_en_i) begin
          linked_data_q[i]  <= linked_data_d[i];
          // only if this slot is in use, that is to say there is an outstanding transaction
          if (!linked_data_q[i].free) begin 
            case (linked_data_q[i].write_state) 
              WRITE_ADDRESS: begin
                // Counter 0: AW Phase - AW_VALID to AW_READY, handshake is checked meanwhile
                if (mst_req_i.aw_valid && !slv_rsp_i.aw_ready) begin
                  linked_data_q[i].counters.cnt_awvalid_awready <= linked_data_q[i].counters.cnt_awvalid_awready + 1 ; // note: cannot do auto-increment
                end
                // Counter 1: AW Phase - AW_VALID to W_VALID (first data) 
                linked_data_q[i].counters.cnt_awvalid_wfirst <= linked_data_q[i].counters.cnt_awvalid_wfirst + 1;
              end
          
              WRITE_DATA: begin
                // Counter 2: W Phase - W_VALID to W_READY (first data), handshake of first data is checked
                if (mst_req_i.w_valid && !slv_rsp_i.w_ready) begin
                  linked_data_q[i].counters.cnt_wvalid_wready_first  <= linked_data_q[i].counters.cnt_wvalid_wready_first + 1;
                end
                // Counter 3: W Phase - W_VALID to W_LAST 
                linked_data_q[i].counters.cnt_wfirst_wlast  <= linked_data_q[i].counters.cnt_wfirst_wlast + 1;
                // Timeout check W state
              end

              WRITE_RESPONSE: begin
                // Counter 4: B Phase - W_LAST to B_VALID, handshake is checked, stop counting upon handshake
                if(mst_req_i.b_ready && !slv_rsp_i.b_valid) begin
                  linked_data_q[i].counters.cnt_wlast_bvalid <= linked_data_q[i].counters.cnt_wlast_bvalid + 1;
                end
                //  Counter 5: B Phase - B_VALID to B_READY
                linked_data_q[i].counters.cnt_wlast_bready <= linked_data_q[i].counters.cnt_wlast_bready +1;
                // Timeout check B state 
              end 
            endcase
          end
        end
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      reset_req_q <= 1'b0;
      irq_q <= '0;
    end else begin
      // Latch reset request
      if (reset_req) begin
        reset_req_q <= 1'b1;
        irq_q <= 1'b1;
      end else if (reset_clear_i) begin
        reset_req_q <= 1'b0;
        irq_q <= 1'b0;
      end
    end
  end

  assign   reset_req_o = reset_req_q;
  assign   irq_o = irq_q;

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

