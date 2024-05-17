module read_guard #(
  parameter int unsigned MaxUniqIds = 0,
  parameter int unsigned MaxRdTxns = 0, 
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
  output logic       reset_req_o,
  output logic       irq_o,
  // register configs
  input  reg2hw_t    reg2hw_i,
  output hw2reg_t    hw2reg_o
);
  logic  inp_req;
  logic  inp_gnt;
  logic  oup_gnt;
  logic  reset_req, irq;
  logic  oup_data_valid;
  
  assign inp_req = mst_req_i.ar_valid;
  assign hw2reg_o.irq.mis_id_wr.de = 1'b1;
  assign hw2reg_o.irq.r0.de = 1'b1;
  assign hw2reg_o.irq.r1.de = 1'b1;
  assign hw2reg_o.irq.r2.de = 1'b1;
  assign hw2reg_o.irq.r3.de = 1'b1;
  assign hw2reg_o.irq_addr.de = 1'b1;
  assign hw2reg_o.reset.de = 1'b1; 

  assign reset_req_o = reset_req;
  assign irq_o = irq;

  cnt_t  budget_arvld_arrdy;
  cnt_t  budget_arvld_rvld;
  cnt_t  budget_rvld_rrdy;
  cnt_t  budget_rvld_rlast;

  assign budget_arvld_arrdy = reg2hw_i.budget_arvld_arrdy.q;
  assign budget_arvld_rvld  = reg2hw_i.budget_arvld_rvld.q;
  assign budget_rvld_rrdy   = reg2hw_i.budget_rvld_rrdy.q;
  assign budget_rvld_rlast  = reg2hw_i.budget_rvld_rlast.q;

  // Capacity of the head-tail table, which associates an ID with corresponding head and tail indices.
  localparam int HtCapacity = (MaxUniqIds <= MaxRdTxns) ? MaxUniqIds : MaxRdTxns;
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
    logic [CntWidth -1:0] cnt_arvalid_arready; // AWVALID to AWREADY
    logic [CntWidth -1:0] cnt_arvalid_rfirst;  // AWVALID to WFIRST
    logic [CntWidth -1:0] cnt_rvalid_rready_first; // WVALID to WREADY of WFIRST
    logic [CntWidth -1:0] cnt_rfirst_rlast;    // WFIRST to WLAST
  } read_cnters_t;

  // state enum of the FSM
  typedef enum logic [1:0] {
    IDLE,
    READ_ADDRESS,
    READ_DATA,
    READ_RESPONSE
  } read_state_t;

  // Type of an entry in the linked data table.
  typedef struct packed {
    aw_chan_t       metadata;
    logic           timeout;
    read_state_t    read_state;
    read_cnters_t   counters; 
    ld_idx_t        next;
    logic           free;
  } linked_data_t;

  head_tail_t [HtCapacity-1:0]    head_tail_d,    head_tail_q;
    
  // Array of linked data
  linked_data_t [MaxRdTxns-1:0]    linked_data_d,  linked_data_q;

  logic                           full,
                                  match_in_id_valid,
                                  match_out_id_valid,
                                  no_in_id_match,
                                  no_out_id_match;

  logic [HtCapacity-1:0]          head_tail_free,
                                  idx_matches_in_id,
                                  idx_matches_out_id;

  logic [MaxRdTxns-1:0]           linked_data_free;
 

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
    slv_req_o.ar_valid = mst_req_i.ar_valid;
    mst_rsp_o.ar_ready = slv_rsp_i.ar_ready;
    slv_req_o.ar = mst_req_i.ar;
    slv_req_o.r_ready = mst_req_i.r_ready;
    mst_rsp_o.r_valid = slv_rsp_i.r_valid;
    mst_rsp_o.r = slv_rsp_i.r;

    if (guard_ena_i) begin
      slv_req_o.ar_valid = mst_req_i.ar_valid & !reset_req;
      mst_rsp_o.ar_ready = slv_rsp_i.ar_ready || reset_req;
      slv_req_o.ar = mst_req_i.ar & !reset_req;
      slv_req_o.r_ready = mst_req_i.r_ready && !reset_req;
      mst_rsp_o.r_valid = slv_rsp_i.r_valid || reset_req;
      mst_rsp_o.r = slv_rsp_i.r && !reset_req;
    end
   
    for ( int i = 0; i < MaxRdTxns; i++ ) begin 
      case ( linked_data_q[i].read_state )
        IDLE: begin
          if ( mst_req_i.ar_valid ) begin
            linked_data_d[i].read_state = READ_ADDRESS;
          end
        end
        READ_ADDRESS: begin
          if ( slv_rsp_i.r_valid && !linked_data_q[i].timeout ) begin
            linked_data_d[i].read_state = READ_DATA;
          end
          if (linked_data_q[i].counters.cnt_arvalid_arready >= budget_arvld_arrdy
            || linked_data_d[i].counters.cnt_arvalid_rfirst  >= budget_arvld_rvld) begin
            linked_data_d[i].timeout = 1'b1;
            reset_req = 1'b1;
            oup_req  = 1;
            oup_id = linked_data_q[i].metadata.id;
            linked_data_d[i].read_state = IDLE; 
            end
        end
        READ_DATA: begin
          if ( slv_rsp_i.r.last && !linked_data_q[i].timeout ) begin
            linked_data_d[i].read_state = IDLE;
          end
          if (linked_data_q[i].counters.cnt_rvalid_rready_first >= budget_rvld_rrdy 
            || linked_data_q[i].counters.cnt_rfirst_rlast  >= budget_rvld_rlast) begin
            linked_data_d[i].timeout = 1'b1;
            reset_req = 1'b1;
            oup_req  = 1;
            oup_id = linked_data_q[i].metadata.id;
            mst_rsp_o.r.resp = 2'b10;   
            linked_data_d[i].read_state = IDLE;
          end
          // dequeue in both faulty and fault-free case
          // handshake, id match and no timeout, successul completion
          if ( mst_req_i.r_ready && slv_rsp_i.r_valid && !linked_data_q[i].timeout && (linked_data_q[i].metadata.id == slv_rsp_i.r.id )) begin
            oup_req  = 1;
            oup_id = linked_data_q[i].metadata.id;
            linked_data_d[i].read_state = IDLE;
          end else begin 
            if( mst_req_i.r_ready & slv_rsp_i.r_valid  && !linked_data_q[i].timeout ) begin
              oup_req = 1;
              oup_id = linked_data_q[i].metadata.id;
              // write into reg for mismatch id also reset
              reset_req = 1'b1;
              hw2reg_o.irq.mis_id_rd.d = 1'b1;
              mst_rsp_o.r.resp = 2'b10;   
              hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id;
              linked_data_d[i].read_state = IDLE;
            end else if( mst_req_i.b_ready & slv_rsp_i.b_valid && (linked_data_q[i].metadata.id == slv_rsp_i.r.id )) begin
              // there is still timeout
              oup_req = 1;
              oup_id = linked_data_q[i].metadata.id;
              mst_rsp_o.r.resp = 2'b10;   
              // write into reg for timeout
              reset_req = 1'b1;
              linked_data_d[i].read_state = IDLE;
            end else begin
              oup_req = 1;
              oup_id = linked_data_q[i].metadata.id;
              mst_rsp_o.r.resp = 2'b10;   
              // write into reg for timeout
              reset_req = 1'b1;
              linked_data_d[i].read_state = IDLE;
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
        linked_data_d[head_tail_q[match_out_idx].head].read_state     = IDLE;
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
    if (inp_req && inp_gnt ) begin
      match_in_id = mst_req_i.ar.id;
      match_in_id_valid = 1'b1;
      // If output data was popped for this ID, which lead the head_tail to be popped,
      // then repopulate this head_tail immediately.
      if (oup_ht_popped && (oup_id == mst_req_i.ar.id)) begin
        head_tail_d[match_out_idx] = '{
          id: mst_req_i.ar.id,
          head: oup_data_free_idx,
          tail: oup_data_free_idx,
          free: 1'b0
        };
        linked_data_d[oup_data_free_idx] = '{
          metadata: mst_req_i.ar,
          timeout: 0,
          read_state: READ_ADDRESS,
          counters: 0,
          next: '0,
          free: 1'b0
        };
      end else if (no_in_id_match) begin
        // Else, if no head_tail corresponds to the input id, and no same ID just popped.
        // reuse any freed up entry
        if (oup_ht_popped) begin
          head_tail_d[match_out_idx] = '{
            id: mst_req_i.ar.id,
            head: oup_data_free_idx,
            tail: oup_data_free_idx,
            free: 1'b0
          };
          linked_data_d[oup_data_free_idx] = '{
          metadata: mst_req_i.ar,
          timeout: 0,
          read_state: READ_ADDRESS,
          counters: 0,
          next: '0,
          free: 1'b0
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
              timeout: 0,
              read_state: READ_ADDRESS,
              counters: 0,
              next: '0, 
              free: 1'b0
            };
            end else begin
              head_tail_d[head_tail_free_idx] = '{
                id: mst_req_i.ar.id,
                head: linked_data_free_idx,
                tail: linked_data_free_idx,
                free: 1'b0
              };
              linked_data_d[oup_data_free_idx] = '{
                metadata: mst_req_i.ar,
                timeout: 0,
                read_state: READ_ADDRESS,
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
              metadata: mst_req_i.ar,
              timeout: 0,
              read_state: READ_ADDRESS,
              counters: 0,
              next: '0,
              free: 1'b0
            };
          end else begin
            linked_data_d[head_tail_q[match_in_idx].tail].next = linked_data_free_idx;
            head_tail_d[match_in_idx].tail = linked_data_free_idx;
            linked_data_d[oup_data_free_idx] = '{
              metadata: mst_req_i.ar,
              timeout: 0,
              read_state: READ_ADDRESS,
              counters: 0,
              next: '0,
              free: 1'b0
            };
          end
        end
      end
    end

  for (genvar i = 0; i < MaxRdTxns; i++) begin: proc_counter
   /// state transitions and counter updates
   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        linked_data_q[i] <= '0;
        // mark all slots as free
        linked_data_q[i].read_state <= IDLE;
        linked_data_q[i][0] <= 1'b1;
      end else begin
        if (guard_ena_i) begin
          linked_data_q[i]  <= linked_data_d[i];
          // only if this slot is in use, that is to say there is an outstanding transaction
          if (!linked_data_q[i].free) begin 
            case (linked_data_q[i].read_state) 
              IDLE: begin
                  linked_data_q[i] <= '0;
                  linked_data_q[i].read_state <= IDLE;
                  linked_data_q[i][0] <= 1'b1;
              end
              READ_ADDRESS: begin
                // Counter 0: AR Phase - AR_VALID to AR_READY, handshake is checked meanwhile
                if (mst_req_i.ar_valid && !slv_rsp_i.ar_ready) begin
                  linked_data_q[i].counters.cnt_arvalid_arready <= linked_data_q[i].counters.cnt_arvalid_arready + 1 ; // note: cannot do auto-increment
                end
                // Counter 1: AR Phase - AR_VALID to R_VALID (first data)
                linked_data_q[i].counters.cnt_arvalid_rfirst <= linked_data_q[i].counters.cnt_arvalid_rfirst + 1;
              end
          
              READ_DATA: begin
                // Counter 2: R Phase - R_VALID to R_READY (first data), handshake of first data is checked
                if (slv_rsp_i.r_valid && !mst_req_i.r_ready) begin
                  linked_data_q[i].counters.cnt_rvalid_rready_first  <= linked_data_q[i].counters.cnt_rvalid_rready_first + 1;
                end
                // Counter 3: R Phase - R_VALID to R_LAST
                linked_data_q[i].counters.cnt_rfirst_rlast  <= linked_data_q[i].counters.cnt_rfirst_rlast + 1;
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
        assert (MaxRdTxns >= 1)
            else $fatal(1, "The queue must have capacity of at least one entry!");
    end
`endif
`endif
endmodule