// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

// Authors:
// - Chaoqun Liang <chaoqun.liang@unibo.it>

module read_guard
  import slv_pkg::*;
#(
  /// Maximum number of unique IDs
  parameter int unsigned MaxUniqIds    = 32,
  /// Maximum read transactions
  parameter int unsigned MaxRdTxns     = 32,
  /// Prescaler division value
  parameter int unsigned PrescalerDiv  = 1,
  parameter int unsigned AccuCntWidth  = 1,
  parameter type accu_cnt_t            = logic,
  parameter type hs_cnt_t              = logic,
  parameter type cnt_t                 = logic,
  /// AXI request type
  parameter type req_t                 = logic,
  /// AXI response type
  parameter type rsp_t                 = logic,
  /// ID type
  parameter type id_t                  = logic,
  /// Read request channel type
  parameter type meta_t                = logic,
  /// Regbus type
  parameter type reg2hw_t              = logic,
  parameter type hw2reg_t              = logic
)(
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic       wr_rst_i,
  // Transaction enqueue request
  input  logic       rd_en_i,
  // Request from master
  input  req_t       mst_req_i,
  // Response from slave
  input  rsp_t       slv_rsp_i,
  // Reset state
  input  logic       reset_clear_i,
  // Slave request request
  output logic       reset_req_o,
  // Interrupt line
  output logic       irq_o,
  // register configs
  input  reg2hw_t    reg2hw_i,
  output hw2reg_t    hw2reg_o
);

  // Unit Budget time from ar_valid to ar_ready
  hs_cnt_t  budget_arvld_arrdy;
  // Unit Budget time from r_valid to r_ready
  hs_cnt_t  budget_rvld_rrdy;

  assign budget_arvld_arrdy = reg2hw_i.budget_arvld_arrdy.q;
  assign budget_rvld_rrdy   = reg2hw_i.budget_rvld_rrdy.q;

  // Capacity of the head-tail table, which associates an ID with corresponding head and tail indices.
  localparam int HtCapacity = (MaxUniqIds <= MaxRdTxns) ? MaxUniqIds : MaxRdTxns;
  localparam int unsigned HtIdxWidth = cf_math_pkg::idx_width(HtCapacity);
    localparam int unsigned LdIdxWidth = cf_math_pkg::idx_width(MaxRdTxns);

  // Type for indexing the head-tail table.
  typedef logic [HtIdxWidth-1:0] ht_idx_t;
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
    // ARVALID to ARREADY
    hs_cnt_t cnt_arvalid_arready;
    // ARVALID to RVALID
    accu_cnt_t cnt_arvalid_rfirst;
    // RVALID to RREADY
    hs_cnt_t cnt_rvalid_rready_first;
    // RVALID to RLAST
    cnt_t cnt_rfirst_rlast;
  } read_cnters_t;

  // Type of an entry in the linked data table.
  typedef struct packed {
    meta_t          metadata;
    read_state_t    read_state;
    read_cnters_t   counters;
    // txn-specific dynamic budget
    accu_cnt_t      r1_budget;
    cnt_t           r3_budget;
    ld_idx_t        next;
    logic           free;
  } linked_rd_data_t;

  // R fifo
  localparam int unsigned PtrWidth = $clog2(MaxRdTxns);
  // FIFO storage for transaction indices
  logic [LdIdxWidth-1:0] [MaxRdTxns-1:0] r_fifo;
  // Write and read pointers
  logic [PtrWidth-1:0] wr_ptr_d, wr_ptr_q, rd_ptr_d, rd_ptr_q;
  // Status signals
  logic fifo_full_d, fifo_full_q, fifo_empty_d, fifo_empty_q;

  // Head tail table entry
  head_tail_t [HtCapacity-1:0]    head_tail_d,    head_tail_q;

  // Array of linked data
  linked_rd_data_t [MaxRdTxns-1:0]   linked_data_d,  linked_data_q;

  logic                           full,
                                  match_in_id_valid,
                                  no_in_id_match;

  logic [HtCapacity-1:0]          head_tail_free,
                                  idx_matches_in_id,
                                  idx_rsp_id;

  logic [MaxRdTxns-1:0]           linked_data_free;

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
    ) i_rd_id_lookup (
      .match_in_id_valid   ( match_in_id_valid    ),
      .match_in_id         ( match_in_id          ),
      .rsp_id              ( slv_rsp_i.r.id       ),
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
  ) i_rd_id_ohb_in (
    .onehot ( idx_matches_in_id ),
    .bin    ( match_in_idx      )
  );

  onehot_to_bin #(
    .ONEHOT_WIDTH ( HtCapacity )
  ) i_rd_id_ohb_rsp (
    .onehot ( idx_rsp_id    ),
    .bin    ( rsp_idx       )
  );

  ht_free #(
    .HtCapacity ( HtCapacity  ),
    .head_tail_t( head_tail_t )
  ) i_rd_ht_free (
    .head_tail_q      ( head_tail_q    ),
    .head_tail_free_o ( head_tail_free )
  );

  lzc #(
    .WIDTH ( HtCapacity ),
    .MODE  ( 0          ) // Start at index 0.
  ) i_rd_ht_free_lzc (
    .in_i    ( head_tail_free     ),
    .cnt_o   ( head_tail_free_idx ),
    .empty_o (                    )
  );

  ld_free #(
    .MaxTxns       ( MaxRdTxns        ),
    .linked_data_t ( linked_rd_data_t )
  ) i_rd_ld_free (
    .linked_data_q_i    ( linked_data_q    ),
    .linked_data_free_o ( linked_data_free )
  );

  lzc #(
    .WIDTH ( MaxRdTxns ),
    .MODE  ( 0        ) // Start at index 0.
  ) i_rd_ld_free_lzc (
        .in_i    ( linked_data_free     ),
        .cnt_o   ( linked_data_free_idx ),
        .empty_o (                      )
  );

  // The queue is full if and only if there are no free items in the linked data structure.
  assign full = !(|linked_data_free);
  assign active_idx = r_fifo[rd_ptr_q];

  dynamic_budget #(
    .MaxTxns      ( MaxRdTxns        ),     // Maximum number of transactions
    .PrescalerDiv ( PrescalerDiv     ),
    .accu_cnt_t   ( accu_cnt_t       ),
    .linked_data_t( linked_rd_data_t )
  ) i_rd_dynamic_budget (
    .linked_data_q_i ( linked_data_q      ),
    .accum_burst_len ( accum_burst_length ) // Total accumulated burst length
  );

  logic prescaled_en;
  prescaler #(
    .DivFactor ( PrescalerDiv )
    )i_rd_prescaler(
    .clk_i       ( clk_i        ),
    .rst_ni      ( rst_ni       ),
    .prescaled_o ( prescaled_en )
  );

  logic ar_ready_sticky;
  logic r_valid_sticky, r_ready_sticky;
  logic r_last_sticky;

  sticky_bit i_arready_sticky (
    .clk_i      ( clk_i              ),
    .rst_ni     ( rst_ni             ),
    .release_i  ( prescaled_en       ),
    .sticky_i   ( slv_rsp_i.ar_ready ),
    .sticky_o   ( ar_ready_sticky    )
  );

  sticky_bit i_rvalid_sticky (
    .clk_i      ( clk_i             ),
    .rst_ni     ( rst_ni            ),
    .release_i  ( prescaled_en      ),
    .sticky_i   ( slv_rsp_i.r_valid ),
    .sticky_o   ( r_valid_sticky    )
  );

  sticky_bit i_rready_sticky (
    .clk_i      ( clk_i             ),
    .rst_ni     ( rst_ni            ),
    .release_i  ( prescaled_en      ),
    .sticky_i   ( mst_req_i.r_ready ),
    .sticky_o   ( r_ready_sticky    )
  );

  sticky_bit i_rlast_sticky (
    .clk_i      ( clk_i             ),
    .rst_ni     ( rst_ni            ),
    .release_i  ( prescaled_en      ),
    .sticky_i   ( slv_rsp_i.r.last  ),
    .sticky_o   ( r_last_sticky     )
  );

  rd_txn_manager #(
    .MaxRdTxns         ( MaxRdTxns          ),
    .HtCapacity        ( HtCapacity         ),
    .PtrWidth          ( PtrWidth           ),
    .LdIdxWidth        ( LdIdxWidth         ),
    .PrescalerDiv      ( PrescalerDiv       ),
    .linked_data_t     ( linked_rd_data_t   ),
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
  ) i_rd_txn_manager (
    .rd_en_i               ( rd_en_i              ),
    .wr_rst_i              ( wr_rst_i             ),
    .full_i                ( full                 ),
    .r_fifo_o              ( r_fifo               ),
    .accum_burst_length    ( accum_burst_length   ),
    .budget_arvld_arrdy_i  ( budget_arvld_arrdy   ),
    .budget_rvld_rrdy_i    ( budget_rvld_rrdy     ),
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
    ) i_rd_ht_ff (
      .clk_i        ( clk_i          ),
      .rst_ni       ( rst_ni         ),
      .head_tail_d_i( head_tail_d[i] ),
      .head_tail_q_o( head_tail_q[i] )
    );
  end
  endgenerate

  generate
  for (genvar i = 0; i < MaxRdTxns; i++) begin: gen_rd_counter
    rd_counter #(
      .linked_data_t ( linked_rd_data_t ),
      .CntWidth      ( AccuCntWidth     ),
      .id_t          ( id_t             )
    ) i_rd_counter (
      .clk_i             ( clk_i                ),
      .rst_ni            ( rst_ni               ),
      .prescaled_en_i    ( prescaled_en         ),
      .slv_r_id_i        ( slv_rsp_i.r.id       ),
      .ar_ready_sticky_i ( ar_ready_sticky      ),
      .r_last_sticky_i   ( r_last_sticky        ),
      .r_valid_sticky_i  ( r_valid_sticky       ),
      .r_ready_sticky_i  ( r_ready_sticky       ),
      .linked_data_d_i   ( linked_data_d[i]     ),
      .linked_data_q_o   ( linked_data_q[i]     )
    );
  end
  endgenerate

  reset_handler #(
    .PtrWidth      ( PtrWidth  )
  )i_rd_reset_handler(
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

  assign   reset_req_o = reset_req_q;
  assign   irq_o = irq;

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
