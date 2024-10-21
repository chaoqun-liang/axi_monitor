// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

// Authors:
// - Chaoqun Liang <chaoqun.liang@unibo.it>

module write_guard 
  import slv_pkg::*;
#(
  /// Maximum number of unique IDs
  parameter int unsigned MaxUniqIds   = 32,
  /// Maximum write transactions
  parameter int unsigned MaxWrTxns    = 32,
  /// Counter width 
  parameter int unsigned CntWidth     = 8,
  parameter int unsigned HsCntWidth   = 8,
  /// Prescaler division value 
  parameter int unsigned PrescalerDiv = 1,
  // Accumulative Counterwidth. Don't Override. 
  parameter int unsigned AccuCntWidth = CntWidth-$clog2(PrescalerDiv)+1,
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
  input  logic       rd_rst_i,
  /// Transaction enqueue request
  input  logic       wr_en_i,
  /// Request from master
  input  req_t       mst_req_i,
  /// Response from slave
  input  rsp_t       slv_rsp_i, 
  /// Reset state 
  input  logic       reset_clear_i,
  /// Reset request 
  output logic       reset_req_o,
  /// Interrupt line
  output logic       irq_o,
  /// Register bus
  input  reg2hw_t    reg2hw_i,
  output hw2reg_t    hw2reg_o
);

  // Unit Budget time from aw_valid to aw_ready
  hs_cnt_t  budget_awvld_awrdy;
  // Unit Budget time from w_valid to w_ready (of w_first)
  hs_cnt_t  budget_wvld_wrdy;
  // Unit Budget time from w_last to b_valid
  hs_cnt_t  budget_wlast_bvld;
  // Unit Budget time from w_last to b_ready
  hs_cnt_t  budget_bvld_brdy;

  assign budget_awvld_awrdy = reg2hw_i.budget_awvld_awrdy.q;
  assign budget_wvld_wrdy   = reg2hw_i.budget_wvld_wrdy.q;
  assign budget_wlast_bvld  = reg2hw_i.budget_wlast_bvld.q;
  assign budget_bvld_brdy   = reg2hw_i.budget_bvld_brdy.q;
 
  /// Capacity of the head-tail table, which associates an ID with corresponding head and tail indices.
  localparam int HtCapacity = (MaxUniqIds <= MaxWrTxns) ? MaxUniqIds : MaxWrTxns;
  localparam int unsigned HtIdxWidth = cf_math_pkg::idx_width(HtCapacity);

  /// Type for indexing the head-tail table.
  typedef logic [HtIdxWidth-1:0] ht_idx_t;

  /// Type of an entry in the head-tail table.
  typedef struct packed {
    id_t        id;
    ld_idx_t    head,
                tail;
    logic       free;
  } head_tail_t;

  // W fifo
  localparam int unsigned PtrWidth = $clog2(MaxWrTxns);
  // FIFO storage for transaction indices 
  logic [LdIdxWidth-1:0] [MaxWrTxns-1:0] w_fifo; 
  // Write and read pointers
  logic [PtrWidth-1:0] wr_ptr_d, wr_ptr_q, rd_ptr_d, rd_ptr_q;
  // Status signals
  logic fifo_full_d, fifo_full_q, fifo_empty_d, fifo_empty_q; 
 
  // Head tail table entry 
  head_tail_t [HtCapacity-1:0]    head_tail_d,    head_tail_q;
    
  // Array of linked data
  linked_wr_data_t [MaxWrTxns-1:0]   linked_data_d,  linked_data_q;

  logic                           full,
                                  match_in_id_valid,
                                  no_in_id_match;

  logic [HtCapacity-1:0]          head_tail_free,
                                  idx_matches_in_id,
                                  idx_rsp_id;

  logic [MaxWrTxns-1:0]           linked_data_free;
 
  id_t                            match_in_id, oup_id;

  ht_idx_t                        head_tail_free_idx,
                                  match_in_idx,
                                  rsp_idx;

  ld_idx_t                        linked_data_free_idx,
                                  oup_data_free_idx,
                                  active_idx;

  logic                           oup_data_valid,                           
                                  oup_data_popped,
                                  oup_req,
                                  oup_ht_popped;
  
  logic                           reset_req, reset_req_q,
                                  id_exists, irq, 
                                  timeout, timeout_q; 

  accu_cnt_t                      accum_burst_length;                            
  
  // Find the index in the head-tail table that matches a given ID.
  generate
  for (genvar i = 0; i < HtCapacity; i++) begin: gen_idx_lookup
    id_lookup #(
      .id_t        ( id_t         ),
      .head_tail_t ( head_tail_t  )
    ) i_wr_id_lookup (
      .match_in_id_valid   ( match_in_id_valid    ),
      .match_in_id         ( match_in_id          ),
      .rsp_id              ( slv_rsp_i.b.id       ),
      .head_tail_q_i       ( head_tail_q[i]       ),
      .idx_matches_in_id_o ( idx_matches_in_id[i] ),
      .idx_rsp_id_o        ( idx_rsp_id[i]        )
    );
  end
  endgenerate

  assign no_in_id_match = !(|idx_matches_in_id);
  assign id_exists =  (|idx_rsp_id);

  onehot_to_bin #(
    .ONEHOT_WIDTH ( HtCapacity )
  ) i_wr_id_ohb_in (
    .onehot ( idx_matches_in_id ),
    .bin    ( match_in_idx      )
  );
 
  onehot_to_bin #(
    .ONEHOT_WIDTH ( HtCapacity )
  ) i_wr_id_ohb_rsp (
    .onehot ( idx_rsp_id    ),
    .bin    ( rsp_idx       )
  );

  ht_free #(
    .HtCapacity ( HtCapacity  ),
    .head_tail_t( head_tail_t )
  ) i_wr_ht_free (
    .head_tail_q      ( head_tail_q    ),
    .head_tail_free_o ( head_tail_free ) 
  );

  lzc #(
    .WIDTH ( HtCapacity ),
    .MODE  ( 0          ) // Start at index 0
  ) i_wr_ht_free_lzc (
    .in_i    ( head_tail_free     ),
    .cnt_o   ( head_tail_free_idx ),
    .empty_o (                    )
  );

  ld_free #(
    .MaxTxns       ( MaxWrTxns        ),
    .linked_data_t ( linked_wr_data_t )
  ) i_wr_ld_free (
    .linked_data_q_i    ( linked_data_q    ),
    .linked_data_free_o ( linked_data_free )
  );

  lzc #(
    .WIDTH ( MaxWrTxns ),
    .MODE  ( 0        ) // Start at index 0.
  ) i_wr_ld_free_lzc (
    .in_i    ( linked_data_free     ),
    .cnt_o   ( linked_data_free_idx ),
    .empty_o (                      )
  );
 
  // The queue is full if and only if there are no free items in the linked data structure.
  assign full = !(|linked_data_free);
  assign active_idx = w_fifo[rd_ptr_q];

  dynamic_budget #(
    .MaxTxns      ( MaxWrTxns        ),     // Maximum number of transactions  
    .PrescalerDiv ( PrescalerDiv     ),
    .accu_cnt_t   ( accu_cnt_t       ),
    .linked_data_t( linked_wr_data_t )
  ) i_wr_dynamic_budget (
    .linked_data_q_i ( linked_data_q      ),
    .accum_burst_len ( accum_burst_length ) // Total accumulated burst length
  );
  
  logic prescaled_en;
  prescaler #(
    .DivFactor ( PrescalerDiv )
  ) i_wr_prescaler (
    .clk_i       ( clk_i        ),
    .rst_ni      ( rst_ni       ),
    .prescaled_o ( prescaled_en )
  ); 

  logic aw_ready_sticky;
  logic w_valid_sticky, w_ready_sticky;
  logic b_valid_sticky, b_ready_sticky;

  sticky_bit i_awready_sticky (
    .clk_i     ( clk_i              ),
    .rst_ni    ( rst_ni             ),
    .release_i ( prescaled_en       ),
    .sticky_i  ( slv_rsp_i.aw_ready ),
    .sticky_o  ( aw_ready_sticky    )
  );

  sticky_bit i_wvalid_sticky (
    .clk_i     ( clk_i             ),
    .rst_ni    ( rst_ni            ),
    .release_i ( prescaled_en      ),
    .sticky_i  ( mst_req_i.w_valid ),
    .sticky_o  ( w_valid_sticky    )
  );

  sticky_bit i_wready_sticky (
    .clk_i     ( clk_i             ),
    .rst_ni    ( rst_ni            ),
    .release_i ( prescaled_en      ),
    .sticky_i  ( slv_rsp_i.w_ready ),
    .sticky_o  ( w_ready_sticky    )
  );

  sticky_bit i_bvalid_sticky (
    .clk_i     ( clk_i             ),
    .rst_ni    ( rst_ni            ),
    .release_i ( prescaled_en      ),
    .sticky_i  ( slv_rsp_i.b_valid ),
    .sticky_o  ( b_valid_sticky    )
  );

  sticky_bit i_bready_sticky (
    .clk_i     ( clk_i             ),
    .rst_ni    ( rst_ni            ),
    .release_i ( prescaled_en      ),
    .sticky_i  ( mst_req_i.b_ready ),
    .sticky_o  ( b_ready_sticky    )
  );

  wr_txn_manager #(
    .MaxWrTxns         ( MaxWrTxns          ),
    .HtCapacity        ( HtCapacity         ),
    .PtrWidth          ( PtrWidth           ),
    .LdIdxWidth        ( LdIdxWidth         ),
    .PrescalerDiv      ( PrescalerDiv       ),
    .linked_data_t     ( linked_wr_data_t   ),
    .head_tail_t       ( head_tail_t        ),
    .ht_idx_t          ( ht_idx_t           ),
    .ld_idx_t          ( ld_idx_t           ),
    .req_t             ( req_t              ),
    .rsp_t             ( rsp_t              ),
    .id_t              ( id_t               ),
    .accu_cnt_t        ( accu_cnt_t         ),
    .hs_cnt_t          ( hs_cnt_t           ),
    .cnt_t             ( cnt_t              ),
    .hw2reg_t          ( hw2reg_t           ),
    .reg2hw_t          ( reg2hw_t           )
  ) i_wr_txn_manager (
    .wr_en_i               ( wr_en_i              ),
    .rd_rst_i              ( rd_rst_i             ),
    .full_i                ( full                 ),
    .w_fifo_o              ( w_fifo               ),
    .budget_awvld_awrdy_i  ( budget_awvld_awrdy   ),
    .budget_wlast_bvld_i   ( budget_wlast_bvld    ),
    .budget_bvld_brdy_i    ( budget_bvld_brdy     ),
    .budget_wvld_wrdy_i    ( budget_wvld_wrdy     ),
    .accum_burst_length    ( accum_burst_length   ),
    .id_exists_i           ( id_exists            ),
    .rsp_idx_i             ( rsp_idx              ),
    .active_idx_i          ( active_idx           ),
    .mst_req_i             ( mst_req_i            ),
    .slv_rsp_i             ( slv_rsp_i            ),
    .head_tail_free_idx_i  ( head_tail_free_idx   ),
    .match_in_idx_i        ( match_in_idx         ),
    .linked_data_free_idx_i( linked_data_free_idx ),
    .wr_ptr_q_i            ( wr_ptr_q             ),
    .rd_ptr_q_i            ( rd_ptr_q             ),
    .fifo_full_q_i         ( fifo_full_q          ),
    .fifo_empty_q_i        ( fifo_empty_q         ),
    .wr_ptr_d_o            ( wr_ptr_d             ),
    .rd_ptr_d_o            ( rd_ptr_d             ), 
    .fifo_full_d_o         ( fifo_full_d          ), 
    .fifo_empty_d_o        ( fifo_empty_d         ),
    .no_in_id_match_i      ( no_in_id_match       ),
    .timeout_o             ( timeout              ),
    .timeout_q_i           ( timeout_q            ),
    .reset_req             ( reset_req            ),
    .oup_req               ( oup_req              ),
    .oup_id                ( oup_id               ),
    .match_in_id           ( match_in_id          ),
    .match_in_id_valid     ( match_in_id_valid    ),
    .oup_data_valid        ( oup_data_valid       ),
    .oup_data_popped       ( oup_data_popped      ),
    .oup_ht_popped         ( oup_ht_popped        ),
    .head_tail_q           ( head_tail_q          ),
    .head_tail_d           ( head_tail_d          ),
    .linked_data_q         ( linked_data_q        ),
    .linked_data_d         ( linked_data_d        ),
    .hw2reg_o              ( hw2reg_o             ),
    .reg2hw_i              ( reg2hw_i             )
  );

  generate
  // HT table registers
  for (genvar i = 0; i < HtCapacity; i++) begin: gen_ht_ffs
    ht_ff #(
      .head_tail_t  ( head_tail_t )
    ) i_wr_ht_ff (
      .clk_i        ( clk_i          ),
      .rst_ni       ( rst_ni         ),
      .head_tail_d_i( head_tail_d[i] ),
      .head_tail_q_o( head_tail_q[i] )
    );
  end
  endgenerate

  generate
  for (genvar i = 0; i < MaxWrTxns; i++) begin: gen_wr_counter
    wr_counter #(
      .linked_data_t ( linked_wr_data_t ),
      .CntWidth      ( AccuCntWidth     ), 
      .id_t          ( id_t             )
    ) i_wr_counter (
      .clk_i           ( clk_i                 ),             
      .rst_ni          ( rst_ni                ), 
      .slv_b_id_i      ( slv_rsp_i.b.id        ),
      .aw_ready_i      ( slv_rsp_i.aw_ready    ),
      .w_ready_i       ( slv_rsp_i.w_ready     ),
      .w_valid_i       ( mst_req_i.w_valid     ),
      .b_valid_i       ( slv_rsp_i.b_valid     ),   
      .b_ready_i       ( mst_req_i.b_ready     ),    
      .linked_data_d_i ( linked_data_d[i]      ), 
      .linked_data_q_o ( linked_data_q[i]      )  
    );
  end
  endgenerate

  reset_handler #(
    .PtrWidth      ( PtrWidth  )
  )i_wr_reset_handler(
    .clk_i         ( clk_i         ),
    .rst_ni        ( rst_ni        ),
    .timeout_i     ( timeout       ),
    .timeout_q_o   ( timeout_q     ),
    .reset_req_i   ( reset_req     ),
    .reset_clear_i ( reset_clear_i ),
    .reset_req_q_o ( reset_req_q   ),
    .irq_o         ( irq           ),
    .wr_ptr_d_i    ( wr_ptr_d      ),
    .rd_ptr_d_i    ( rd_ptr_d      ),
    .fifo_empty_d_i( fifo_empty_d  ),
    .fifo_full_d_i ( fifo_full_d   ),
    .wr_ptr_q_o    ( wr_ptr_q      ),
    .rd_ptr_q_o    ( rd_ptr_q      ),
    .fifo_empty_q_o( fifo_empty_q  ),
    .fifo_full_q_o ( fifo_full_q   )
  );

  assign  reset_req_o = reset_req_q;
  assign  irq_o = irq;

 // Validate parameters.
 `ifndef SYNTHESIS
 `ifndef COMMON_CELLS_ASSERTS_OFF
    initial begin: validate_params
        assert (CntWidth >= 0)
           else $fatal(1, "AccuCntWidth must be non-zero!");
        assert (MaxWrTxns >= 1)
            else $fatal(1, "The queue must have capacity of at least one entry!");
    end
 `endif
 `endif
endmodule