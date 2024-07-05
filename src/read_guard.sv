// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

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
  // ID type
  parameter type id_t  = logic,
  parameter type ar_chan_t = logic,
  parameter type reg2hw_t  = logic,
  parameter type hw2reg_t  = logic
)(
  input  logic       clk_i,
  input  logic       rst_ni,
  // Transaction enqueue request
  input  logic       rd_en_i,
  // Request from master
  input  req_t       mst_req_i,  
  // Response from slave
  input  rsp_t       slv_rsp_i,
  // Slave request request
  output logic       reset_req_o,
  // Interrupt line
  output logic       irq_o,
  // Reset state
  input  logic       reset_clear_i,
  // register configs
  input  reg2hw_t    reg2hw_i,
  output hw2reg_t    hw2reg_o
);

  assign hw2reg_o.irq.unwanted_txn.de = 1'b1;
  assign hw2reg_o.irq.txn_id.de = 1'b1;
  assign hw2reg_o.irq_addr.de = 1'b1;
  assign hw2reg_o.reset.de = 1'b1; 
  assign hw2reg_o.latency_read.de = 1'b1;
  
  typedef logic [CntWidth-1:0] cnt_t;

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
  linked_data_t [MaxRdTxns-1:0]   linked_data_d,  linked_data_q;

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

  logic [MaxRdTxns-1:0]           linked_data_free;
 
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
  
  logic                           id_exists,
                                  oup_req, 
                                  reset_req, reset_req_q,
                                  irq;

  cnt_t                           txn_budget;


  // Find the index in the head-tail table that matches a given ID.
  for (genvar i = 0; i < HtCapacity; i++) begin: gen_idx_match
    assign idx_matches_in_id[i] = match_in_id_valid && (head_tail_q[i].id == match_in_id) && !head_tail_q[i].free;
    assign idx_matches_out_id[i] = match_out_id_valid && (head_tail_q[i].id == match_out_id) && !head_tail_q[i].free;
    assign idx_rsp_id[i] = (head_tail_q[i].id == slv_rsp_i.r.id) && !head_tail_q[i].free;
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

  // To calculate the total burst lengths.
  logic [CntWidth-1:0] accum_burst_length;

  always_comb begin: proc_accum_length
    accum_burst_length = 0;
    for (int i = 0; i < MaxRdTxns; i++) begin
      if (!linked_data_q[i].free) begin
        accum_burst_length += linked_data_q[i].metadata.len;
      end
    end
  end

  always_comb begin : proc_rd_queue
    match_in_id         = '0;
    match_out_id        = '0;
    match_in_id_valid   = 1'b0;
    match_out_id_valid  = 1'b0;
    head_tail_d         = head_tail_q;
    linked_data_d       = linked_data_q;
    oup_data_valid      = 1'b0;
    oup_data_popped     = 1'b0;
    oup_ht_popped       = 1'b0;
    oup_id              = 1'b0;
    oup_req             = 1'b0;
    irq                 = 1'b0;
    reset_req           = reset_req_q;
    hw2reg_o.irq.unwanted_txn.d = reg2hw_i.irq.unwanted_txn.q;
    hw2reg_o.irq.txn_id.d       = reg2hw_i.irq.txn_id.q;
    hw2reg_o.irq_addr.d         = reg2hw_i.irq_addr.q;
    hw2reg_o.reset.d            = reg2hw_i.reset.q;
    hw2reg_o.latency_read.d    = reg2hw_i.latency_read.q;

    // Enqueue
    if (rd_en_i && inp_gnt ) begin : proc_txn_enqueue
      match_in_id = mst_req_i.ar.id;
      match_in_id_valid = 1'b1;
      txn_budget = budget_read * (accum_burst_length + mst_req_i.ar.len); 
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
          counter: txn_budget,
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
            counter: txn_budget,
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
              counter: txn_budget,
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
              counter: txn_budget,
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
            counter: txn_budget,
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
            counter: txn_budget,
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
        if (linked_data_q[i].counter < 0) begin 
          linked_data_d[i].timeout = 1'b1;
          reset_req = 1'b1;
          hw2reg_o.irq_addr.d = linked_data_q[i].metadata.addr;
          hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id;
          hw2reg_o.reset.d = 1'b1;
          irq = 1'b1;
        end 
        if ( slv_rsp_i.r.last && slv_rsp_i.r_valid && mst_req_i.r_ready && !linked_data_q[i].timeout ) begin
          if( id_exists ) begin
            linked_data_d[i].found_match = ((linked_data_q[i].metadata.id == slv_rsp_i.r.id) && (head_tail_q[rsp_idx].head == i) )? 1'b1 : 1'b0;
          end else begin 
            hw2reg_o.irq.unwanted_txn.d = 'b1;
            hw2reg_o.reset.d = 1'b1;
            reset_req = 1'b1;
            irq = 1'b1;
          end
        end
        if ( linked_data_q[i].found_match) begin
          oup_req = 1; 
          oup_id = linked_data_q[i].metadata.id;
          hw2reg_o.latency_read.d = linked_data_q[i].counter;
        end
      end
    end

    if(reset_req) begin 
      // clear all LD slots
      for (int i = 0; i < MaxRdTxns; i++ ) begin
        if (!linked_data_q[i].free) begin 
          linked_data_d[i]          = '0;
          linked_data_d[i].free     = 1'b1;
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
        linked_data_d[head_tail_q[match_out_idx].head].free     = 1'b1;
        // If it is the last cell of this ID
        if (head_tail_q[match_out_idx].head == head_tail_q[match_out_idx].tail) begin
          oup_ht_popped = 1'b1;
          head_tail_d[match_out_idx] = '{free: 1'b1, default: '0};
        end else begin
          head_tail_d[match_out_idx].head = linked_data_q[head_tail_q[match_out_idx].head].next;
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

  for (genvar i = 0; i < MaxRdTxns; i++) begin: gen_rd_counter
    /// state transitions and counter updates
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        linked_data_q[i] <= '0;
        linked_data_q[i][0] <= 1'b1;
      end else begin
        linked_data_q[i]  <= linked_data_d[i];
        // only if this slot is in use, that is to say there is an outstanding transaction
        if (!linked_data_q[i].free) begin 
          if (!linked_data_q[i].found_match && !linked_data_q[i].timeout) begin
            linked_data_q[i].counter <= linked_data_q[i].counter - 1 ; // note: cannot do auto-increment
          end      
        end
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      reset_req_q <= 1'b0;
    end else begin
      // Latch reset request
      if (reset_req) begin
        reset_req_q <= 1'b1;
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
    assert (MaxRdTxns >= 1)
      else $fatal(1, "The queue must have capacity of at least one entry!");
    end
`endif
`endif
endmodule