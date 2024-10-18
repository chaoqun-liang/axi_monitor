// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

// Authors:
// - Chaoqun Liang <chaoqun.liang@unibo.it>

module write_guard #(
  /// Maximum number of unique IDs
  parameter int unsigned MaxUniqIds   = 32,
  /// Maximum write transactions
  parameter int unsigned MaxWrTxns    = 32,
  /// AXI request type
  parameter type req_t                = logic,
  /// AXI response type
  parameter type rsp_t                = logic,
  /// ID type
  parameter type id_t                 = logic,
  parameter type num_cnt_t            = logic,
  parameter type track_cnt_t          = logic,
  /// Regbus type
  parameter type reg2hw_t             = logic,
  parameter type hw2reg_t             = logic
)(
  input  logic       clk_i,
  input  logic       rst_ni,
  /// Transaction enqueue request
  input  logic       wr_en_i,

  input  track_cnt_t budget,

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

  /// Capacity of the head-tail table, which associates an ID with corresponding head and tail indices.
  localparam int IdCapacity = (MaxUniqIds <= MaxWrTxns) ? MaxUniqIds : MaxWrTxns;
  localparam int unsigned HtIdxWidth = cf_math_pkg::idx_width(IdCapacity);
 
  /// Type for indexing the head-tail table.
  typedef logic [HtIdxWidth-1:0] id_idx_t;


  /// Type of an entry in the id table.
  typedef struct packed {
    id_t        id;
    num_cnt_t   num_txn;
    track_cnt_t txn_budget;
    logic       free;
  } id_track_t;
  
  // id table entry 
  id_track_t [IdCapacity-1:0]     id_track_d, id_track_q;

  logic                           full,
                                  match_in_id_valid,
                                  no_in_id_match,
                                  no_out_id_match;

  logic [IdCapacity-1:0]          id_table_free,
                                  idx_matches_in_id,
                                  idx_matches_out_id,
                                  idx_rsp_id;
 
  id_t                            match_in_id, oup_id;

  id_idx_t                        id_table_free_idx,
                                  match_in_idx,
                                  rsp_idx;

  logic                           oup_req;
  
  logic                           reset_req, reset_req_q,
                                  rsp_id_exists,
                                  irq, timeout;                              
  
  // Find the index in the id table that matches a given ID.
  generate
  for (genvar i = 0; i < IdCapacity; i++) begin: gen_idx_lookup
    id_lookup #(
      .id_t        ( id_t         ),
      .id_track_t  ( id_track_t   )
    ) i_wr_id_lookup (
      .match_in_id_valid   ( match_in_id_valid    ),
      .match_in_id         ( match_in_id          ),
      .rsp_id              ( slv_rsp_i.b.id       ),
      .id_track_q_i        ( id_track_q[i]        ),
      .idx_matches_in_id_o ( idx_matches_in_id[i] ),
      .idx_rsp_id_o        ( idx_rsp_id[i]        )
    );
  end
  endgenerate

  assign no_in_id_match = !(|idx_matches_in_id);
  assign rsp_id_exists =  (|idx_rsp_id);

  onehot_to_bin #(
    .ONEHOT_WIDTH ( IdCapacity )
  ) i_wr_id_ohb_in (
    .onehot ( idx_matches_in_id ),
    .bin    ( match_in_idx      )
  );
 
  onehot_to_bin #(
    .ONEHOT_WIDTH ( IdCapacity )
  ) i_wr_id_ohb_rsp (
    .onehot ( idx_rsp_id    ),
    .bin    ( rsp_idx       )
  );
  
  id_free #(
    .IdCapacity ( IdCapacity  ),
    .id_track_t ( id_track_t  )
  ) i_wr_id_free (
    .id_track_q      ( id_track_q     ),
    .id_free_o       ( id_table_free  ) 
  );

  lzc #(
    .WIDTH ( IdCapacity ),
    .MODE  ( 0          ) // Start at index 0
  ) i_wr_id_free_lzc (
    .in_i    ( id_table_free      ),
    .cnt_o   ( id_table_free_idx  ),
    .empty_o (                    )
  );
 
  // The queue is full if and only if there are no free items in the id table structure.
  assign full = !(|id_table_free);
  
  wr_txn_manager #(
    .IdCapacity        ( IdCapacity         ), 
    .id_track_t        ( id_track_t         ),
    .id_idx_t          ( id_idx_t           ),
    .track_cnt_t       ( track_cnt_t        ),
    .req_t             ( req_t              ),
    .rsp_t             ( rsp_t              ),
    .id_t              ( id_t               ),
    .hw2reg_t          ( hw2reg_t           ),
    .reg2hw_t          ( reg2hw_t           )
  ) i_wr_txn_manager (
    .wr_en_i               ( wr_en_i              ),
    .full_i                ( full                 ),
    .txn_budget            ( budget               ),
    .id_exists_i           ( rsp_id_exists        ),
    .rsp_idx_i             ( rsp_idx              ),
    .mst_req_i             ( mst_req_i            ),
    .slv_rsp_i             ( slv_rsp_i            ),
    .id_table_free_idx_i   ( id_table_free_idx    ),
    .match_in_idx_i        ( match_in_idx         ),
    .no_in_id_match_i      ( no_in_id_match       ),
    .timeout               ( timeout              ),
    .reset_req             ( reset_req            ),
    .oup_req               ( oup_req              ),
    .oup_id                ( oup_id               ),
    .match_in_id           ( match_in_id          ),
    .match_in_id_valid     ( match_in_id_valid    ),
    .id_track_q            ( id_track_q           ),
    .id_track_d            ( id_track_d           ),
    .hw2reg_o              ( hw2reg_o             ),
    .reg2hw_i              ( reg2hw_i             )
  );

  generate
  for (genvar i = 0; i < IdCapacity; i++) begin: gen_wr_counter
    wr_counter #(
      .IdCapacity     ( IdCapacity  ),
      .id_track_t     ( id_track_t  ),
      .track_cnt_t    ( track_cnt_t ),  // Set the width of the counter
      .id_idx_t       ( id_idx_t    ),
      .id_t           ( id_t        )
    ) i_wr_counter (
      .clk_i           ( clk_i             ),             
      .rst_ni          ( rst_ni            ),          
      .budget          ( budget            ),    
      .b_valid         ( slv_rsp_i.b_valid ),   
      .b_ready         ( mst_req_i.b_ready ),
      .slv_rsp_id_i    ( slv_rsp_i.b.id    ),
      .idx_rsp_id      ( idx_rsp_id        ),  
      .id_track_d_i    ( id_track_d[i]     ), 
      .id_track_q_o    ( id_track_q[i]     )  
    );
  end
  endgenerate

  reset_handler i_wr_reset_handler(
    .clk_i         ( clk_i         ),
    .rst_ni        ( rst_ni        ),
    .reset_req_i   ( reset_req     ),
    .reset_clear_i ( reset_clear_i ),
    .reset_req_q_o ( reset_req_q   ),
    .irq_o         ( irq           )
  );

  assign  reset_req_o = reset_req_q;
  assign  irq_o = irq;

endmodule
