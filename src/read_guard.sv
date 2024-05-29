
module read_guard #(
  // Maximum number of unique IDs
  parameter int unsigned MaxUniqIds = 0,
  // Maximum read transactions
  parameter int unsigned MaxRdTxns  = 0, 
  // Counter width 
  parameter int unsigned CntWidth   = 0,
  // AXI request type
  parameter type req_t = logic,
  // AXI response type
  parameter type rsp_t = logic,
  // Budget type
  parameter type cnt_t = logic,
  // ID type
  parameter type id_t  = logic,
  // Read address channel type
  parameter type ar_chan_t = logic,
  parameter type reg2hw_t = logic,
  parameter type hw2reg_t = logic
)(
  input  logic       clk_i,
  input  logic       rst_ni,
  // Read guard enable
  input  logic       guard_ena_i,
  // Transaction enqueue request
  input  logic       inp_req_i,
  // Request from master
  input  req_t       mst_req_i,  
  // Request to master
  output rsp_t       mst_rsp_o,
  // Response from slave
  input  rsp_t       slv_rsp_i,
  // Response to slave
  output req_t       slv_req_o,
  // Slave request request
  output logic       reset_req_o,
  output logic       irq_o,
  input  logic       reset_clear_i,
  // register configs
  input  reg2hw_t    reg2hw_i,
  output hw2reg_t    hw2reg_o
);

  assign hw2reg_o.irq.mis_id_rd.de = 1'b1;
  assign hw2reg_o.irq.unwanted_txn.de = 1'b1;
  assign hw2reg_o.irq_addr.de = 1'b1;
  assign hw2reg_o.reset.de = 1'b1; 
  assign hw2reg_o.latency_read.de = 1'b1;
  
  cnt_t  budget_read;
  assign budget_read = reg2hw_i.budget_read.q;

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
  
  // Type of an entry in the linked data table.
  typedef struct packed {
    ar_chan_t       metadata;
    logic           timeout;
    cnt_t           counter; 
    logic           found_match;
    ld_idx_t        next;
    logic           free;
  } linked_data_t;
  
  // Head tail table entry
  head_tail_t [HtCapacity-1:0]    head_tail_d,    head_tail_q;
    
  // Array of linked data
  linked_data_t [MaxRdTxns-1:0]    linked_data_d,  linked_data_q;
 
  logic                           reset_req_latch, 
                                  irq_latch;

  logic                           inp_gnt,
                                  oup_gnt,                           
                                  full,
                                  match_in_id_valid,
                                  match_out_id_valid,
                                  no_in_id_match,
                                  no_out_id_match;

  logic [HtCapacity-1:0]          head_tail_free,
                                  idx_matches_in_id,
                                  idx_matches_out_id;

  logic [MaxRdTxns-1:0]           linked_data_free,
                                  rsp_id_exists;
 
  id_t                            match_in_id, match_out_id, oup_id;

  ht_idx_t                        head_tail_free_idx,
                                  match_in_idx,
                                  match_out_idx;

  ld_idx_t                        linked_data_free_idx,
                                  oup_data_free_idx;

  logic                           oup_data_valid,                    
                                  oup_data_popped,
                                  oup_ht_popped;
  
  logic                           id_exists,
                                  oup_req,
                                  reset_req,
                                  irq;

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

  for (genvar i = 0; i < MaxRdTxns; i++) begin: gen_id_exists
    assign rsp_id_exists[i] = (linked_data_q[i].metadata.id == slv_rsp_i.b.id);
  end
  assign id_exists =  (|rsp_id_exists);

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

  always_comb begin : proc_rd_queue
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
    
    // Dequeue 
    if (oup_req) begin
      match_out_id = oup_id;
      match_out_id_valid = 1'b1;
      if (!no_out_id_match) begin
        oup_data_valid = 1'b1;
        oup_data_popped = 1;
        // Set free bit of linked data entry, all other bits are don't care.
        linked_data_d[head_tail_q[match_out_idx].head]          = '0;
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
    // Enqueue
    if (inp_req_i && inp_gnt ) begin
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
          counter: 0,
          found_match: 0,
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
          counter: 0,
          found_match: 0,
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
              counter: 0,
              found_match: 0,
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
            linked_data_d[linked_data_free_idx] = '{
              metadata: mst_req_i.ar,
              timeout: 0,
              counter: 0,
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
            metadata: mst_req_i.ar,
            timeout: 0,
            counter: 0,
            found_match: 0,
            next: '0,
            free: 1'b0
          };
        end else begin
          linked_data_d[head_tail_q[match_in_idx].tail].next = linked_data_free_idx;
          head_tail_d[match_in_idx].tail = linked_data_free_idx;
          linked_data_d[linked_data_free_idx] = '{
            metadata: mst_req_i.ar,
            timeout: 0,
            counter: 0,
            found_match: 0,
            next: '0,
            free: 1'b0
          };
        end
      end
    end
    // Transaction states handling
    for ( int i = 0; i < MaxRdTxns; i++ ) begin : proc_rd_txn_states
      if (!linked_data_q[i].free) begin 
        linked_data_d[i].timeout = (linked_data_q[i].counter >= budget_read) ? 1'b1 : 1'b0;
    
        if (slv_rsp_i.r_valid && mst_req_i.r_ready && !linked_data_d[i].timeout) begin
          // if no match, keep comparing
          if( id_exists ) begin
            if ( !linked_data_q[i].found_match) begin
              // if no match yet, determine if there's a match and update status
              linked_data_d[i].found_match = (linked_data_q[i].metadata.id == slv_rsp_i.r.id) ? 1'b1 : 1'b0;
            end else begin 
              oup_req = 1; 
              oup_id = linked_data_q[i].metadata.id;
              hw2reg_o.latency_read.d = linked_data_q[i].counter;
              linked_data_d[i]               = '0;
              linked_data_d[i].free          = 1'b1; 
            end
          end else begin 
            hw2reg_o.irq.unwanted_txn.d = 1'b1;
            hw2reg_o.reset.d = 1'b1;
            reset_req = 1'b1;
            irq = 1'b1;
          end 
        end else begin 
          if( linked_data_d[i].timeout ) begin 
            hw2reg_o.irq_addr.d = linked_data_q[i].metadata.addr;
            hw2reg_o.reset.d = 1'b1;
            reset_req = 1'b1;
            irq = 1'b1;
            oup_req  = 1;
            oup_id = linked_data_q[i].metadata.id;
            linked_data_d[i]               = '0;
            linked_data_d[i].free          = 1'b1; 
          end
        end
      end
    end 
  end
  
  always_comb begin: proc_output_txn
    // pass through when there is no timeout
    slv_req_o.ar_valid  = mst_req_i.ar_valid;
    mst_rsp_o.ar_ready  = slv_rsp_i.ar_ready;
    slv_req_o.ar        = mst_req_i.ar;
    mst_rsp_o.r_valid   = slv_rsp_i.r_valid;
    slv_req_o.r_ready   = mst_req_i.r_ready;
    mst_rsp_o.r         = slv_rsp_i.r;

    // Iterate over all transactions to apply transaction-specific discards
    for (int i = 0; i < MaxRdTxns; i++) begin
      if (linked_data_q[i].timeout) begin
        slv_req_o.ar_valid  = 1'b0;
        mst_rsp_o.ar_ready  = 1'b0;
        slv_req_o.ar        = 'b0;           
        mst_rsp_o.r_valid   = 1'b0;
        slv_req_o.r_ready   = 1'b0;
        mst_rsp_o.r         = 'b0;
      end
    end
  end

  assign   reset_req_o = reset_req;
  assign   irq_o = irq;

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

  for (genvar i = 0; i < MaxRdTxns; i++) begin: gen_rd_counter
   /// state transitions and counter updates
   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        linked_data_q[i] <= '0;
        linked_data_q[i][0] <= 1'b1;
        // reset_req_latch <= 1'b0;
        // irq_latch <= '0;
      end else begin
        if (guard_ena_i) begin
          linked_data_q[i]  <= linked_data_d[i];
           // Latch reset request
          // if (reset_req) begin
          //   reset_req_latch <= 1'b1;
          //   irq_latch <= 1'b1;
          // end else if (reset_clear_i) begin
          //   reset_req_latch <= 1'b0;
          //   irq_latch <= 1'b0;
          // end
          // only if this slot is in use, that is to say there is an outstanding transaction
          if (!linked_data_q[i].free) begin 
            if (!linked_data_q[i].found_match && !linked_data_q[i].timeout) begin
              linked_data_q[i].counter <= linked_data_q[i].counter + 1 ; // note: cannot do auto-increment
            end      
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