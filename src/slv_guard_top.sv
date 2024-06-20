// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Thomas Benz <tbenz@iis.ee.ethz.ch>

`include "axi/typedef.svh"
`include "common_cells/registers.svh"

module slv_guard_top #(
  parameter int unsigned AddrWidth     = 0,
  parameter int unsigned DataWidth     = 0,
  parameter int unsigned StrbWidth     = 0,
  parameter int unsigned AxiIdWidth    = 0,
  parameter int unsigned AxiUserWidth  = 0,
  
  parameter int unsigned MaxUniqIds    = 4,
  parameter int unsigned MaxTxnsPerId  = 4, 
  // DONT OVERRIDE
  parameter int unsigned MaxTxns       = MaxUniqIds * MaxTxnsPerId,
  /// Counter width
  parameter int unsigned CntWidth      = 10,
  /// Subordinate request type
  parameter type req_t                 = logic, 
  /// Subordinate response type
  parameter type rsp_t                 = logic, 
  parameter type int_req_t             = logic,
  parameter type int_rsp_t             = logic,
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
  output int_req_t           req_o,
  /// Response from slave
  input  int_rsp_t           rsp_i,
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
  /// TBD: Reset configuration
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
  logic rst_req;

  assign hw2reg.reset    = hw2reg_w.reset | hw2reg_r.reset;
  assign hw2reg.irq_addr = hw2reg_w.irq_addr | hw2reg_r.irq_addr;
  assign hw2reg.irq      = hw2reg_w.irq | hw2reg_r.irq;
  
  assign reg2hw_w.budget_write = reg2hw.budget_write;
  assign reg2hw_r.budget_read = reg2hw.budget_read;

  // min internal width
  localparam int unsigned IntIdWidth = (MaxUniqIds > 1) ? $clog2(MaxUniqIds) : 1; 

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [StrbWidth-1:0] strb_t;
  typedef logic [AxiIdWidth-1:0] id_t;
  typedef logic [IntIdWidth-1:0] int_id_t;
  typedef logic [AxiUserWidth-1:0] user_t;

  /// Intermediate AXI types
  `AXI_TYPEDEF_AW_CHAN_T(int_aw_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_W_CHAN_T(w_t, data_t, strb_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(int_b_t, int_id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(int_ar_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(int_r_t, data_t, int_id_t, user_t);
  // `AXI_TYPEDEF_REQ_T(int_req_t, int_aw_t, w_t, int_ar_t);
  // `AXI_TYPEDEF_RESP_T(int_rsp_t, int_b_t, int_r_t );

  /// Intermediate AXI channel
  int_req_t  int_req, int_req_wr, int_req_rd;
  int_rsp_t  int_rsp, rd_rsp, wr_rsp;
  
  /// Remap wider ID to narrower ID
  id_remap #(
    .AxiSlvPortIdWidth    ( AxiIdWidth    ),
    .AxiSlvPortMaxUniqIds ( MaxUniqIds    ),
    .AxiMaxTxnsPerId      ( MaxTxnsPerId  ),
    .AxiMstPortIdWidth    ( IntIdWidth    ),
    .slv_req_t            ( req_t         ),
    .slv_resp_t           ( rsp_t         ),
    .mst_req_t            ( int_req_t     ),
    .mst_resp_t           ( int_rsp_t     )
  ) i_id_remap (
    .clk_i,
    .rst_ni,
    .slv_req_i  ( req_i    ),
    .slv_resp_o ( rsp_o    ),
    .mst_req_o  ( int_req  ),
    .mst_resp_i ( int_rsp  )
  );

  logic  wr_enqueue;
  assign wr_enqueue = int_req.aw_valid;
  logic  rd_enqueue;
  assign rd_enqueue = int_req.ar_valid;
  
  // Write
  assign int_req_wr.aw        =  int_req.aw;
  assign int_req_wr.aw_valid  =  int_req.aw_valid;
  assign int_req_wr.w         =  int_req.w;
  assign int_req_wr.w_valid   =  int_req.w_valid;
  assign int_req_wr.b_ready   =  int_req.b_ready;
  // Read
  assign int_req_rd.ar        =  int_req.ar;
  assign int_req_rd.ar_valid  =  int_req.ar_valid;
  assign int_req_rd.r_ready   =  int_req.r_ready;

  // Write
  assign wr_rsp.aw_ready   =  rsp_i.aw_ready;
  assign wr_rsp.w_ready    =  rsp_i.w_ready;
  assign wr_rsp.b          =  rsp_i.b;
  assign wr_rsp.b_valid    =  rsp_i.b_valid;
  // Read
  assign rd_rsp.ar_ready   =  rsp_i.ar_ready;
  assign rd_rsp.r          =  rsp_i.r;
  assign rd_rsp.r_valid    =  rsp_i.r_valid;

  assign rst_req = rst_req_wr | rst_req_rd;
  assign irq_o   =  read_irq  | write_irq;
  assign rst_req_o = rst_req;
  
  write_guard #(
    .MaxUniqIds ( MaxUniqIds ),
    .MaxWrTxns  ( MaxTxns    ), // total writes
    .CntWidth   ( CntWidth   ),
    .req_t      ( int_req_t  ),
    .rsp_t      ( int_rsp_t  ),
    .id_t       ( int_id_t   ),
    .aw_chan_t  ( int_aw_t   ),
    .reg2hw_t   ( slv_guard_reg_pkg::slv_guard_reg2hw_t ),
    .hw2reg_t   ( slv_guard_reg_pkg::slv_guard_hw2reg_t )
  ) i_write_monitor_unit (
    .clk_i,
    .rst_ni,
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
    .MaxUniqIds ( MaxUniqIds ),
    .MaxRdTxns  ( MaxTxns    ), 
    .CntWidth   ( CntWidth   ),
    .req_t      ( int_req_t  ),
    .rsp_t      ( int_rsp_t  ),
    .id_t       ( int_id_t   ),
    .ar_chan_t  ( int_ar_t   ),
    .reg2hw_t   ( slv_guard_reg_pkg::slv_guard_reg2hw_t ),
    .hw2reg_t   ( slv_guard_reg_pkg::slv_guard_hw2reg_t )
  ) i_read_monitor_unit (
    .clk_i,
    .rst_ni,
    .rd_en_i      ( rd_enqueue   ),
    .mst_req_i    ( int_req_rd   ),  
    .slv_rsp_i    ( rd_rsp       ),                                                                               
    .reset_req_o  ( rst_req_rd   ),
    .irq_o        ( read_irq     ),
    .reg2hw_i     ( reg2hw_r     ),
    .hw2reg_o     ( hw2reg_r     )
  );
  
  always_comb begin: proc_output_txn
    // pass through when there is no timeout
    req_o = int_req;
    int_rsp = rsp_i;
    if ( guard_ena_i && rst_req) begin
      req_o = 'b0;
      int_rsp = 'b0;
    end
  end

endmodule