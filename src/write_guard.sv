// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

module write_guard #(
  /// Maximum number of unique IDs
  parameter int unsigned MaxUniqIds   = 32,
  /// Maximum write transactions
  parameter int unsigned MaxWrTxns    = 32,
  /// Counter width 
  parameter int unsigned CntWidth     = 2,
  /// Prescaler division value 
  parameter int unsigned PrescalerDiv = 1,
  // Prescaled accumulative Counterwidth. Don't Override. 
  parameter int unsigned AccuCntWidth = CntWidth-$clog2(PrescalerDiv),
  /// AXI request type
  parameter type req_t                = logic,
  /// AXI response type
  parameter type rsp_t                = logic,
  /// ID type
  parameter type id_t                 = logic,
  /// Write request channel type
  parameter type meta_t               = logic,
  /// Regbus type
  parameter type reg2hw_t             = logic,
  parameter type hw2reg_t             = logic
)(
  input  logic       clk_i,
  input  logic       rst_ni,
  /// Transaction enqueue request
  input  logic       wr_en_i,
  /// Request from master
  input  req_t       mst_req_i,
  /// Response from slave
  input  rsp_t       slv_rsp_i, 
  /// Reset request 
  output logic       reset_req_o,
  /// Interrupt line
  output logic       irq_o,
  /// Reset state 
  input  logic       reset_clear_i,
  /// Register bus
  input  reg2hw_t    reg2hw_i,
  output hw2reg_t    hw2reg_o
);

  /// Counter type based on used-defined counter width
  typedef logic [AccuCntWidth-1:0] accu_cnt_t;

  /// Budget time from aw_valid to aw_ready
  logic [2:0] budget_write; 
  assign budget_write = reg2hw_i.budget_write.q;
 
  /// Capacity of the head-tail table, which associates an ID with corresponding head and tail indices.
  localparam int HtCapacity = (MaxUniqIds <= MaxWrTxns) ? MaxUniqIds : MaxWrTxns;
  localparam int unsigned HtIdxWidth = cf_math_pkg::idx_width(HtCapacity);
  localparam int unsigned LdIdxWidth = cf_math_pkg::idx_width(MaxWrTxns);

  /// Type for indexing the head-tail table.
  typedef logic [HtIdxWidth-1:0] ht_idx_t;

  /// Type for indexing the lined data table.
  typedef logic [LdIdxWidth-1:0] ld_idx_t;

  /// Type of an entry in the head-tail table.
  typedef struct packed {
    id_t        id;
    ld_idx_t    head,
                tail;
    logic       free;
  } head_tail_t;
  
  /// Type of an entry in the linked data table.
  typedef struct packed {
    meta_t          metadata;
    accu_cnt_t      counter;
    logic           found_match;
    ld_idx_t        next;
    logic           free;
  } linked_data_t;

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
                                  oup_data_free_idx;

  logic                           oup_data_valid,                           
                                  oup_data_popped,
                                  oup_req,
                                  oup_ht_popped;
  
  logic                           reset_req, reset_req_q,
                                  id_exists,
                                  irq, timeout;                                
  
  // Find the index in the head-tail table that matches a given ID.
generate
  for (genvar i = 0; i < HtCapacity; i++) begin: gen_idx_lookup
    id_lookup #(
        .id_t        ( id_t         ),
        .head_tail_t ( head_tail_t  )
    ) i_id_lookup (
        .match_in_id_valid   ( match_in_id_valid    ),
        .match_out_id_valid  ( match_out_id_valid   ),
        .match_in_id         ( match_in_id          ),
        .match_out_id        ( match_out_id         ),
        .rsp_id              ( slv_rsp_i.b.id       ),
        .head_tail_q_i       ( head_tail_q[i]       ),
        .idx_matches_in_id_o ( idx_matches_in_id[i] ),
        .idx_matches_out_id_o( idx_matches_out_id[i]),
        .idx_rsp_id_o        ( idx_rsp_id[i]        )
    );
  end
endgenerate

  assign no_in_id_match = !(|idx_matches_in_id);
  assign no_out_id_match = !(|idx_matches_out_id);
  assign id_exists =  (|idx_rsp_id);

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
  
  // Data can be accepted if the linked list pool is not full
  assign inp_gnt = ~full || oup_data_popped;

  // To calculate the total burst lengths at time of request acce
  accu_cnt_t  accum_burst_length, txn_budget;
  always_comb begin: proc_accum_length
    accum_burst_length = 0;
    for (int i = 0; i < MaxWrTxns; i++) begin
      if (!linked_data_q[i].free) begin
        accum_burst_length += ((linked_data_q[i].metadata.len + 1) >> $clog2(PrescalerDiv) + 1);
      end
    end
  end

  logic prescaled_en;
  prescaler #(
    .DivFactor(PrescalerDiv)
    )i_wr_prescaler(
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .prescaled_o(prescaled_en)
  ); 

  logic b_valid_sticky, b_ready_sticky;

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
  
  // txn_track #(
  //   .MaxWrTxns     ( MaxWrTxns      ), 
  //   .HtCapacity    ( HtCapacity     ),
  //   .linked_data_t ( linked_data_t  ),
  //   .head_tail_t   ( head_tail_t    ),
  //   .ht_idx_t      ( ht_idx_t       ),
  //   .id_t          ( id_t           ),
  //   .ld_idx_t      ( ld_idx_t       ),
  //   .hw2reg_t      ( hw2reg_t       ),
  //   .reg2hw_t      ( reg2hw_t       )
  // ) i_txn_track(
  //   .linked_data_q_i      ( linked_data_q     ),
  //   .slv_b_valid_i        ( slv_rsp_i.b_valid ),
  //   .mst_b_ready_i        ( mst_req_i.b_ready ),
  //   .id_exists            ( id_exists         ),
  //   .slv_b_id_i           ( slv_rsp_i.b.id    ),
  //   .head_tail_q_i        ( head_tail_q       ),
  //   .rsp_idx_i            ( rsp_idx           ),
  //   .reset_req_q_i        ( reset_req_q       ),
  //   .prescaled_en         ( prescaled_en      ),
  //   .b_valid_sticky       ( b_valid_sticky    ),
  //   .b_ready_sticky       ( b_ready_sticky    ),
  //   .linked_data_d_o      ( linked_data_d     ),
  //   .timeout_o            ( timeout           ),
  //   .reset_req_o          ( reset_req         ),
  //   .hw2reg_o             ( hw2reg_o          ),
  //   .reg2hw_i             ( reg2hw_i          ),
  //   .oup_req_o            ( oup_req           ),
  //   .oup_id_o             ( oup_id            )
  // );
  
  // txn_dequeue #(
  //   .MaxWrTxns      ( MaxWrTxns     ),
  //   .HtCapacity     ( HtCapacity    ),
  //   .linked_data_t  ( linked_data_t ),
  //   .head_tail_t    ( head_tail_t   ),
  //   .id_t           ( id_t          ),
  //   .ht_idx_t       ( ht_idx_t      )
  // ) i_dequeue (
  //   .oup_req_i         ( oup_req          ),
  //   .no_out_id_match_i ( no_out_id_match  ),
  //   .head_tail_q_i     ( head_tail_q      ),
  //   .linked_data_q_i   ( linked_data_q    ),
  //   .match_out_idx_i   ( match_out_idx    ),
  //   .oup_id_i          ( oup_id           ),
  //   .oup_data_valid_o  ( oup_data_valid   ),
  //   .oup_data_popped_o ( oup_data_popped  ),
  //   .oup_ht_popped_o   ( oup_ht_popped    ),
  //   .head_tail_d_o     ( head_tail_d      ),
  //   .linked_data_d_o   ( linked_data_d    )
  // );

  // txn_enqueue #(
  //   .PrescalerDiv  ( PrescalerDiv  ), 
  //   .MaxWrTxns     ( MaxWrTxns     ),
  //   .HtCapacity    ( HtCapacity    ),
  //   .ht_idx_t      ( ht_idx_t      ),
  //   .linked_data_t ( linked_data_t ),
  //   .accu_cnt_t    ( accu_cnt_t    ),
  //   .int_id_t      ( id_t          ),
  //   .head_tail_t   ( head_tail_t   ),
  //   .ld_idx_t      ( ld_idx_t      ),
  //   .req_t         ( req_t         )
  // ) i_txn_enqueue (
  //   .wr_en_i               ( wr_en_i                ),  // Write enable input
  //   .inp_gnt_i             ( inp_gnt                ),  // Input grant signal
  //   .match_in_idx_i        ( match_in_idx           ),  // Index of matching ID
  //   .match_out_idx_i       ( match_out_idx          ),
  //   .oup_data_free_idx_i   ( oup_data_free_idx      ),
  //   .linked_data_free_idx_i( linked_data_free_idx   ),
  //   .mst_req_i             ( mst_req_i              ),
  //   .head_tail_free_idx_i  ( head_tail_free_idx     ),
  //   .oup_id_i              ( oup_id                 ),
  //   .oup_ht_popped_i       ( oup_data_popped        ),  // Flag indicating if head tail popped
  //   .no_in_id_match_i      ( no_in_id_match         ),  // No matching ID in head tail
  //   .oup_data_popped_i     ( oup_data_popped        ),  // Flag indicating if output data popped
  //   .budget_write_i        ( budget_write           ),  // Unit budget write value
  //   .accum_burst_length_i  ( accum_burst_length     ),  // Accumulated burst length
  //   .mst_aw_id_i           ( mst_req_i.aw.id        ),  // Request ID for AW channel
  //   .mst_aw_len_i          ( mst_req_i.aw.len       ),  // Request length for AW channel
  //   .head_tail_q_i         ( head_tail_q            ),
  //   .head_tail_d_o         ( head_tail_d            ),  // Head-tail data
  //   .linked_data_d_o       ( linked_data_d          )   // Linked data
  // );
  
  txn_manager #(
    .MaxWrTxns         ( MaxWrTxns          ),
    .HtCapacity        ( HtCapacity         ), // this single line can change from 70+ to 18
    .PrescalerDiv      ( PrescalerDiv       ),
    .linked_data_t     ( linked_data_t      ),
    .head_tail_t       ( head_tail_t        ),
    .ht_idx_t          ( ht_idx_t           ),
    .ld_idx_t          ( ld_idx_t           ),
    .req_t             ( req_t              ),
    .rsp_t             ( rsp_t              ),
    .id_t              ( id_t               ),
    .accu_cnt_t        ( accu_cnt_t         ),
    .hw2reg_t          ( hw2reg_t           ),
    .reg2hw_t          ( reg2hw_t           )
  ) i_txn_manager (
    .wr_en_i               ( wr_en_i            ),
    .inp_gnt               ( inp_gnt            ),
    .budget_write          ( budget_write       ),
    .accum_burst_length    ( accum_burst_length ),
    .reset_req_q           ( reset_req_q        ),
    .id_exists_i           ( id_exists          ),
    .rsp_idx_i             ( rsp_idx            ),
    .mst_req_i             ( mst_req_i          ),
    .slv_rsp_i             ( slv_rsp_i          ),
    .no_out_id_match_i     ( no_out_id_match    ),
    .match_out_idx_i       ( match_out_idx      ),
    .head_tail_free_idx_i  (head_tail_free_idx  ),
    .match_in_idx_i        ( match_in_idx       ),
    .oup_data_free_idx_i   ( oup_data_free_idx  ),
    .linked_data_free_idx_i(linked_data_free_idx),
    .no_in_id_match_i      ( no_in_id_match     ),
    .timeout               ( timeout            ),
    .reset_req             ( reset_req          ),
    .oup_req               ( oup_req            ),
    .oup_id                ( oup_id             ),
    .match_out_id          ( match_out_id       ),
    .match_in_id           ( match_in_id        ),
    .match_in_id_valid     ( match_in_id_valid  ),
    .match_out_id_valid    ( match_out_id_valid ),
    .oup_data_valid        ( oup_data_valid     ),
    .oup_data_popped       ( oup_data_popped    ),
    .oup_ht_popped         ( oup_ht_popped      ),
    .head_tail_q           ( head_tail_q        ),
    .head_tail_d           ( head_tail_d        ),
    .linked_data_q         ( linked_data_q      ),
    .linked_data_d         ( linked_data_d      ),
    .hw2reg_o              ( hw2reg_o           ),
    .reg2hw_i              ( reg2hw_i           )
  );

  generate
  // HT table registers
  for (genvar i = 0; i < HtCapacity; i++) begin: gen_ht_ffs
    ht_ff #(
      .head_tail_t(head_tail_t)
    ) i_ht_ff (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .head_tail_d_i(head_tail_d[i]),
      .head_tail_q_o(head_tail_q[i])
    );
  end
  endgenerate

  // number of counters are not accurate here
  generate
  for (genvar i = 0; i < MaxWrTxns; i++) begin: gen_wr_counter
    wr_counter #(
      .linked_data_t ( linked_data_t ),
      .CntWidth      ( AccuCntWidth  )  // Set the width of the counter
    ) i_wr_counter (
      .clk_i           ( clk_i            ),             
      .rst_ni          ( rst_ni           ),          
      .prescaled_en    ( prescaled_en     ),    
      .b_valid_sticky  ( b_valid_sticky   ),   
      .b_ready_sticky  ( b_ready_sticky   ),    
      .linked_data_d_i ( linked_data_d[i] ), 
      .linked_data_q_o ( linked_data_q[i] )  
    );
  end
  endgenerate

  reset_handler i_reset_handler(
    .clk_i         ( clk_i         ),
    .rst_ni        ( rst_ni        ),
    .reset_req_i   ( reset_req     ),
    .reset_clear_i ( reset_clear_i ),
    .reset_req_q_o ( reset_req_q   ),
    .irq_o         ( irq           )
  );

  assign  reset_req_o = reset_req_q;
  assign irq_o = irq;

 // Validate parameters.
 `ifndef SYNTHESIS
 `ifndef COMMON_CELLS_ASSERTS_OFF
    initial begin: validate_params
        assert (CntWidth-$clog2(PrescalerDiv) >= 0)
           else $fatal(1, "AccuCntWidth must be non-zero!");
        assert (MaxWrTxns >= 1)
            else $fatal(1, "The queue must have capacity of at least one entry!");
    end
 `endif
 `endif
endmodule
