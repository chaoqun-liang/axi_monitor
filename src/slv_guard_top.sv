// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

`include "axi/typedef.svh"
`include "common_cells/registers.svh"

module slv_guard_top
  //import slv_pkg::*;
#(
  parameter int unsigned AddrWidth     = 48,
  parameter int unsigned DataWidth     = 32,
  parameter int unsigned StrbWidth     = 4,
  parameter int unsigned AxiIdWidth    = 6,
  parameter int unsigned AxiUserWidth  = 1,

  parameter int unsigned MaxUniqIds    = 32,
  parameter int unsigned MaxTxnsPerId  = 1,
  parameter int unsigned MaxTxns       = MaxUniqIds * MaxTxnsPerId,
  /// Counter width
  parameter int unsigned CounterWidth  = 10,
  parameter int unsigned HsCntWidth    = 2,
  parameter int unsigned PrescalerDiv  = 8,
  parameter int unsigned CntWidth      = CounterWidth-$clog2(PrescalerDiv),
  parameter int unsigned AccuCntWidth  = CounterWidth-$clog2(PrescalerDiv)+1,
  /// Master request type
  parameter type req_t                 = logic,
  /// Master response type
  parameter type rsp_t                 = logic,
  /// Subordinate request type
  parameter type slv_req_t             = logic,
  /// Subordinate response type
  parameter type slv_rsp_t             = logic,
  /// Configuration register bus request type
  parameter type reg_req_t             = logic,
  /// Configuration register bus response type
  parameter type reg_rsp_t             = logic
)(
  /// Clock
  input  logic               clk_i,
  /// Asynchronous reset
  input  logic               rst_ni,
  /// Guard enable
  input  logic               guard_ena_i,
  /// Request from manager
  input  req_t               req_i,
  /// Response to manager
  output rsp_t               rsp_o,
  /// Request to slave
  output slv_req_t           req_o,
  /// Response from slave
  input  slv_rsp_t           rsp_i,
  /// Register bus request
  input  reg_req_t           reg_req_i,
  /// Register bus response
  output reg_rsp_t           reg_rsp_o,
  /// Interrupt line
  output logic               irq_o,
  /// Reset request
  output logic               rst_req_o,
  /// Reset status
  input  logic               rst_stat_i
);

  // register signals
  slv_guard_reg_pkg::slv_guard_reg2hw_t reg2hw, reg2hw_w, reg2hw_r;
  slv_guard_reg_pkg::slv_guard_hw2reg_t hw2reg, hw2reg_w, hw2reg_r;

  slv_guard_reg_top #(
    .reg_req_t(reg_req_t),
    .reg_rsp_t(reg_rsp_t)
  ) i_regs (
    .clk_i,
    .rst_ni,
    .reg_req_i ( reg_req_i    ),
    .reg_rsp_o ( reg_rsp_o    ),
    .reg2hw    ( reg2hw       ),
    .hw2reg    ( hw2reg       ),
    .devmode_i ( 1'b1         )
  );

  logic rst_req_rd, rst_req_wr;
  logic write_irq, read_irq;
  logic wr_enqueue, rd_enqueue;

  assign hw2reg.reset    = hw2reg_w.reset | hw2reg_r.reset;
  assign hw2reg.irq_addr = hw2reg_w.irq_addr | hw2reg_r.irq_addr;
  assign hw2reg.irq      = hw2reg_w.irq | hw2reg_r.irq;

  assign reg2hw_w.budget_awvld_awrdy  = reg2hw.budget_awvld_awrdy;
  assign reg2hw_w.budget_wvld_wrdy    = reg2hw.budget_wvld_wrdy;
  assign reg2hw_w.budget_unit_w       = reg2hw.budget_unit_w;
  assign reg2hw_w.budget_wlast_bvld   = reg2hw.budget_wlast_bvld;
  assign reg2hw_w.budget_bvld_brdy    = reg2hw.budget_bvld_brdy;

  assign reg2hw_r.budget_arvld_arrdy  = reg2hw.budget_arvld_arrdy;
  assign reg2hw_r.budget_rvld_rrdy    = reg2hw.budget_rvld_rrdy;
  assign reg2hw_r.budget_unit_r       = reg2hw.budget_unit_r;

  // min internal width
  localparam int unsigned IntIdWidth = (MaxUniqIds > 1) ? $clog2(MaxUniqIds) : 1;

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [StrbWidth-1:0] strb_t;
  typedef logic [AxiIdWidth-1:0] id_t;
  typedef logic [IntIdWidth-1:0] int_id_t;
  typedef logic [AxiUserWidth-1:0] user_t;

  typedef logic [AccuCntWidth-1:0] accu_cnt_t;
  typedef logic [CntWidth-1:0] cnt_t;
  typedef logic [HsCntWidth-1:0] hs_cnt_t;

  /// Intermediate AXI types
  `AXI_TYPEDEF_AW_CHAN_T(int_aw_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_W_CHAN_T(w_t, data_t, strb_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(int_b_t, int_id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(int_ar_t, addr_t, int_id_t, user_t);

  /// Intermediate AXI channel
  slv_req_t  int_req, int_req_wr, int_req_rd;
  slv_rsp_t  int_rsp, rd_rsp, wr_rsp;

  typedef struct packed {
    int_id_t        id;
    axi_pkg::len_t  len; // 8 bits
  } meta_t;

  /// Remap wider ID to narrower ID
  axi_id_remap #(
    .AxiSlvPortIdWidth    ( AxiIdWidth    ),
    .AxiSlvPortMaxUniqIds ( MaxUniqIds    ),
    .AxiMaxTxnsPerId      ( MaxTxnsPerId  ),
    .AxiMstPortIdWidth    ( IntIdWidth    ),
    .slv_req_t            ( req_t         ),
    .slv_resp_t           ( rsp_t         ),
    .mst_req_t            ( slv_req_t     ),
    .mst_resp_t           ( slv_rsp_t     )
  ) i_id_remap (
    .clk_i,
    .rst_ni,
    .slv_req_i  ( req_i    ),
    .slv_resp_o ( rsp_o    ),
    .mst_req_o  ( int_req  ),
    .mst_resp_i ( int_rsp  )
  );

  // Write
  always_comb begin
    int_req_wr          = int_req;
    int_req_wr.ar       = 'b0;
    int_req_wr.ar_valid = 'b0;
    int_req_wr.r_ready  = 'b0;
    wr_rsp              = rsp_i;
    wr_rsp.ar_ready     = 'b0;
    wr_rsp.r            = 'b0;
    wr_rsp.r_valid      = 'b0;
  end

  // Read
  always_comb begin
    int_req_rd          = int_req;
    int_req_rd.aw       = 'b0;
    int_req_rd.aw_valid = 'b0;
    int_req_rd.w        = 'b0;
    int_req_rd.w_valid  = 'b0;
    int_req_rd.b_ready  = 'b0;
    rd_rsp              = rsp_i;
    rd_rsp.aw_ready     = 'b0;
    rd_rsp.w_ready      = 'b0;
    rd_rsp.b            = 'b0;
    rd_rsp.b_valid      = 'b0;
  end

  write_guard #(
    .MaxUniqIds   ( MaxUniqIds   ),
    .MaxWrTxns    ( MaxTxns      ), // total writes
    .AccuCntWidth ( AccuCntWidth ),
    .accu_cnt_t   ( accu_cnt_t   ),
    .hs_cnt_t     ( hs_cnt_t     ),
    .cnt_t        ( cnt_t        ),
    .PrescalerDiv ( PrescalerDiv ),
    .req_t        ( slv_req_t    ),
    .rsp_t        ( slv_rsp_t    ),
    .id_t         ( int_id_t     ),
    .meta_t       ( meta_t       ),
    .reg2hw_t     ( slv_guard_reg_pkg::slv_guard_reg2hw_t ),
    .hw2reg_t     ( slv_guard_reg_pkg::slv_guard_hw2reg_t )
  ) i_write_monitor_unit (
    .clk_i,
    .rst_ni,
    .rd_rst_i     ( rst_req_rd   ),
    .wr_en_i      ( wr_enqueue   ),
    .mst_req_i    ( int_req_wr   ),
    .slv_rsp_i    ( wr_rsp       ),
    .reset_req_o  ( rst_req_wr   ),
    .irq_o        ( write_irq    ),
    .reset_clear_i( rst_stat_i   ),
    .reg2hw_i     ( reg2hw_w     ),
    .hw2reg_o     ( hw2reg_w     )
  );

  read_guard #(
    .MaxUniqIds   ( MaxUniqIds   ),
    .MaxRdTxns    ( MaxTxns      ),
    .AccuCntWidth ( AccuCntWidth ),
    .accu_cnt_t   ( accu_cnt_t   ),
    .hs_cnt_t     ( hs_cnt_t     ),
    .cnt_t        ( cnt_t        ),
    .PrescalerDiv ( PrescalerDiv ),
    .req_t        ( slv_req_t    ),
    .rsp_t        ( slv_rsp_t    ),
    .id_t         ( int_id_t     ),
    .meta_t       ( meta_t       ),
    .reg2hw_t     ( slv_guard_reg_pkg::slv_guard_reg2hw_t ),
    .hw2reg_t     ( slv_guard_reg_pkg::slv_guard_hw2reg_t )
  ) i_read_monitor_unit (
    .clk_i,
    .rst_ni,
    .rd_en_i      ( rd_enqueue   ),
    .wr_rst_i     ( rst_req_wr   ),
    .mst_req_i    ( int_req_rd   ),
    .slv_rsp_i    ( rd_rsp       ),
    .reset_req_o  ( rst_req_rd   ),
    .irq_o        ( read_irq     ),
    .reset_clear_i( rst_stat_i   ),
    .reg2hw_i     ( reg2hw_r     ),
    .hw2reg_o     ( hw2reg_r     )
  );

assign rst_req_o = rst_req_wr | rst_req_rd;
assign irq_o     =  read_irq  | write_irq;

always_comb begin
    // Default behavior for req_o and int_rsp
    req_o   = int_req;
    int_rsp = rsp_i;

    // Set default values for enqueue signals
    rd_enqueue = 1'b0;
    wr_enqueue = 1'b0;

    // Conditions for normal operation
    if (guard_ena_i) begin
      rd_enqueue = int_req_rd.ar_valid && !rst_req_o;
      wr_enqueue = int_req_wr.aw_valid && !rst_req_o;
    end

    // Override in case of reset request or interrupt
    if (rst_req_o || irq_o) begin
      req_o      = 'b0;
      int_rsp    = 'b0;
      wr_enqueue = 1'b0;
      rd_enqueue = 1'b0;
    end
  end

endmodule
