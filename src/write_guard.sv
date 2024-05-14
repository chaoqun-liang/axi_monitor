
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
  input  logic       inp_req_i,
  
  input  req_t       mst_req_i,  
  output rsp_t       mst_rsp_o,
  input  rsp_t       slv_rsp_i,
  output req_t       slv_req_o,
  output logic       reset_req_o,
  output logic       irq_o,
  // register configs
  input  reg2hw_t    reg2hw_i,
  output hw2reg_t    hw2reg_o
);

logic  inp_gnt;
logic  oup_gnt;
logic  reset_req, irq;
logic  oup_data_valid;

assign hw2reg_o.irq.mis_id_wr.de = 1'b1;
assign hw2reg_o.irq.w0.de = 1'b1;
assign hw2reg_o.irq.w1.de = 1'b1;
assign hw2reg_o.irq.w2.de = 1'b1;
assign hw2reg_o.irq.w3.de = 1'b1;
assign hw2reg_o.irq.w4.de = 1'b1;
assign hw2reg_o.irq.w5.de = 1'b1;
assign hw2reg_o.irq_addr.de = 1'b1;
assign hw2reg_o.reset.de = 1'b1; 

 
  assign reset_req_o = reset_req;
  assign irq_o = irq;

  cnt_t  budget_awvld_awrdy;
  cnt_t  budget_awvld_wvld;
  cnt_t  budget_wvld_wrdy;
  cnt_t  budget_wvld_wlast;
  cnt_t  budget_wlast_bvld;
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

  typedef struct packed {
    logic [CntWidth -1:0] cnt_awvalid_awready; // AWVALID to AWREADY
    logic [CntWidth -1:0] cnt_awvalid_wfirst;  // AWVALID to WFIRST
    logic [CntWidth -1:0] cnt_wvalid_wready_first; // WVALID to WREADY of WFIRST
    logic [CntWidth -1:0] cnt_wfirst_wlast;    // WFIRST to WLAST
    logic [CntWidth -1:0] cnt_wlast_bvalid;    // WLAST to BVALID
    logic [CntWidth  -1:0] cnt_wlast_bready;   // WLAST to BREADY
  } write_cnters_t;

  // state enum of the FSM
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
    ld_idx_t        next;
    logic           free;
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

  logic [MaxWrTxns-1:0]           linked_data_free;
 

  id_t                            match_in_id, match_out_id, oup_id;

  ht_idx_t                        head_tail_free_idx,
                                  match_in_idx,
                                  match_out_idx;

  ld_idx_t                        linked_data_free_idx,
                                  oup_data_free_idx;

  logic                           oup_data_popped,
                                  oup_ht_popped;
  
  logic                           oup_req;
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
  assign inp_gnt = ~full || oup_data_popped;
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

  always_comb begin
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
    // default assignment
    slv_req_o.aw_valid = mst_req_i.aw_valid;
    mst_rsp_o.aw_ready = slv_rsp_i.aw_ready;
    slv_req_o.aw = mst_req_i.aw;
    slv_req_o.w_valid = mst_req_i.w_valid;
    mst_rsp_o.w_ready = slv_rsp_i.w_ready;
    slv_req_o.w = mst_req_i.w;
    mst_rsp_o.b_valid = slv_rsp_i.b_valid;
    slv_req_o.b_ready = mst_req_i.b_ready;
    mst_rsp_o.b = slv_rsp_i.b;

    if (guard_ena_i) begin
      slv_req_o.aw_valid = mst_req_i.aw_valid & !reset_req;
      mst_rsp_o.aw_ready = slv_rsp_i.aw_ready || reset_req;
      slv_req_o.aw = mst_req_i.aw & !reset_req;
      slv_req_o.w_valid = mst_req_i.w_valid && !reset_req;
      mst_rsp_o.w_ready = slv_rsp_i.w_ready || reset_req;
      slv_req_o.w = mst_req_i.w && !reset_req;
      mst_rsp_o.b_valid = slv_rsp_i.b_valid && !reset_req;
      slv_req_o.b_ready = mst_req_i.b_ready || reset_req;
      mst_rsp_o.b = slv_rsp_i.b && !reset_req;
    end
   
    for ( int i = 0; i < MaxWrTxns; i++ ) begin 
      case ( linked_data_q[i].write_state )
        IDLE: begin
          if ( mst_req_i.aw_valid ) begin
            linked_data_d[i].write_state = WRITE_ADDRESS;
          end
        end
        WRITE_ADDRESS: begin
          if ( mst_req_i.w_valid && !linked_data_q[i].timeout ) begin
            linked_data_d[i].write_state = WRITE_DATA;
          end
          if (linked_data_q[i].counters.cnt_awvalid_awready >= budget_awvld_awrdy
            || linked_data_d[i].counters.cnt_awvalid_wfirst  >= budget_awvld_wvld) begin
            linked_data_d[i].timeout = 1'b1;
            reset_req = 1'b1;
            oup_req  = 1;
            oup_id = linked_data_q[i].metadata.id;
            linked_data_d[i].write_state = IDLE; 
            end
        end
        WRITE_DATA: begin
          if ( mst_req_i.w.last && !linked_data_q[i].timeout ) begin
            linked_data_d[i].write_state = WRITE_RESPONSE;
          end
          if (linked_data_q[i].counters.cnt_wvalid_wready_first >= budget_wvld_wrdy 
            || linked_data_q[i].counters.cnt_wfirst_wlast  >= budget_wvld_wlast) begin
            linked_data_d[i].timeout = 1'b1;
            reset_req = 1'b1;
            oup_req  = 1;
            oup_id = linked_data_q[i].metadata.id;
            mst_rsp_o.b.resp = 2'b10;   
            linked_data_d[i].write_state = IDLE;
          end
        end
        // dequeue in both faulty and fault-free case
        WRITE_RESPONSE: begin
          if (linked_data_q[i].counters.cnt_wlast_bvalid >= budget_wlast_bvld 
            || linked_data_q[i].counters.cnt_wlast_bready >= budget_wlast_brdy) begin
            // reset request in faulty case
            linked_data_d[i].timeout = 1'b1;
            reset_req = 1'b1;
            oup_req  = 1;
            oup_id = linked_data_q[i].metadata.id;
            linked_data_d[i].write_state = IDLE;
            // write into irq regs
            // no timeout, still need to dequeue
          end
          // handshake, id match and no timeout, successul completion
          if ( mst_req_i.b_ready && slv_rsp_i.b_valid && !linked_data_q[i].timeout && (linked_data_q[i].metadata.id == slv_rsp_i.b.id )) begin
            oup_req  = 1;
            oup_id = linked_data_q[i].metadata.id;
            linked_data_d[i].write_state = IDLE;
          end else begin 
            if( mst_req_i.b_ready & slv_rsp_i.b_valid  && !linked_data_q[i].timeout ) begin
              oup_req = 1;
              oup_id = linked_data_q[i].metadata.id;
              // write into reg for mismatch id also reset
              reset_req = 1'b1;
              hw2reg_o.irq.mis_id_wr.d = 1'b1;
              mst_rsp_o.b.resp = 2'b10;   
              hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id;
              linked_data_d[i].write_state = IDLE;
            end else if( mst_req_i.b_ready & slv_rsp_i.b_valid && (linked_data_q[i].metadata.id == slv_rsp_i.b.id )) begin
              // there is still timeout
              oup_req = 1;
              oup_id = linked_data_q[i].metadata.id;
              mst_rsp_o.b.resp = 2'b10;   
              // write into reg for timeout
              reset_req = 1'b1;
              linked_data_d[i].write_state = IDLE;
            end else begin
              oup_req = 1;
              oup_id = linked_data_q[i].metadata.id;
              mst_rsp_o.b.resp = 2'b10;   
              // write into reg for timeout
              reset_req = 1'b1;
              linked_data_d[i].write_state = IDLE;
            // no timeout implies valid handshake 
            end
          end
        end
      endcase 
    end
    if (oup_req) begin
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
      //If there was no match, interrupt with non-requested transactions
      // Always grant the output request.
      oup_gnt = 1'b1;
    end
    /* three main cases*/
    /* 1. ID just popped out HT table, does not exist in HT.*/
    /* 2. Not popped, but does not exist in HT. */
    /* 3. it exits in HT table */
    if (inp_req_i && inp_gnt ) begin
      match_in_id = mst_req_i.aw.id;
      match_in_id_valid = 1'b1;
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
              linked_data_d[oup_data_free_idx] = '{
                metadata: mst_req_i.aw,
                timeout: 0,
                write_state: WRITE_ADDRESS,
                counters: 0,
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
              next: '0,
              free: 1'b0
            };
          end else begin
            linked_data_d[head_tail_q[match_in_idx].tail].next = linked_data_free_idx;
            head_tail_d[match_in_idx].tail = linked_data_free_idx;
            linked_data_d[oup_data_free_idx] = '{
              metadata: mst_req_i.aw,
              timeout: 0,
              write_state: WRITE_ADDRESS,
              counters: 0,
              next: '0,
              free: 1'b0
            };
          end
        end
      end
    end

  for (genvar i = 0; i < MaxWrTxns; i++) begin: proc_counter
   /// state transitions and counter updates
   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        linked_data_q[i] <= '0;
        // mark all slots as free
        linked_data_q[i][0] <= 1'b1;
      end else begin
        if (guard_ena_i) begin
          linked_data_q[i]  <= linked_data_d[i];
          // only if this slot is in use, that is to say there is an outstanding transaction
          if (!linked_data_q[i].free) begin 
            case (linked_data_q[i].write_state) 
              IDLE: begin
                  linked_data_q[i] <= '0;
                  linked_data_q[i][0] <= 1'b1;
              end
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