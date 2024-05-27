// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Thomas Benz <tbenz@iis.ee.ethz.ch>

/// Guards rogue subordinate units
`include "axi/typedef.svh"
`include "common_cells/registers.svh"

module slv_guard_top #(
  parameter int unsigned AddrWidth     = 0,
  parameter int unsigned DataWidth     = 0,
  parameter int unsigned StrbWidth     = 0,
  parameter int unsigned AxiIdWidth    = 0,
  parameter int unsigned AxiUserWidth  = 0,
  /// ID remapper
  parameter int unsigned MaxUniqIds    = 4,
  parameter int unsigned MaxTxnsPerId  = 4, 
  /// Write transaction unique IDs
  parameter int unsigned MaxWrUniqIds  = 4,
  /// Read transaction unique IDs
  parameter int unsigned MaxRdUniqIds  = 4,
  /// Maximum number outstanding write transactions 
  parameter int unsigned MaxWrTxns     = 4,
  /// Maximum number outstanding read transactions 
  parameter int unsigned MaxRdTxns     = 4,
  /// Counter width
  parameter int unsigned CntWidth      = 0,
  /// Internal ID width
  parameter int unsigned IntIdWidth    = 2, 
  /// Subordinate request type
  parameter type req_t                 = logic, 
  /// Subordinate response type
  parameter type rsp_t                 = logic, 
  parameter type slv_req_t             = logic, 
  /// Subordinate response type op
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
  /// Request to subordinate
  output slv_req_t           req_o,
  /// Response from subordinate
  input  slv_rsp_t           rsp_i,
  /// Register bus request
  input  reg_req_t           reg_req_i,
  /// Register bus response
  output reg_rsp_t           reg_rsp_o,
  /// Interrupt line
  output logic               irq_o,
  /// Reset request
  output logic               rst_req_o
  /// Reset status
  //input  logic               rst_stat_i
  /// TBD: Reset configuration
);

  logic rst_req_rd, rst_req_wr;
  logic write_irq, read_irq;
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

  assign hw2reg.reset    = hw2reg_w.reset | hw2reg_r.reset;
  assign hw2reg.irq_addr = hw2reg_w.irq_addr | hw2reg_r.irq_addr;
  assign hw2reg.irq      = hw2reg_w.irq | hw2reg_r.irq;
  
  assign reg2hw_w.budget_write = reg2hw.budget_write;
  assign reg2hw_r.budget_read = reg2hw.budget_read;


  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [StrbWidth-1:0] strb_t;
  typedef logic [AxiIdWidth-1:0] id_t;
  typedef logic [IntIdWidth-1:0] int_id_t;
  typedef logic [AxiUserWidth-1:0] user_t;

 
  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t) ;

  /// Intermediate AXI channel
  slv_req_t  int_req, int_req_wr, int_req_rd, wr_req, rd_req, req_oup;
  slv_rsp_t  int_rsp, rd_rsp, wr_rsp, int_rsp_wr, int_rsp_rd, rsp_inp;
  
  assign req_o = req_oup;
  assign rsp_inp = rsp_i;
  // counter typedef
  typedef logic [CntWidth-1:0] latency_t;

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
  ) i_axi_id_remap (
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
  
  /// Write AW channel 
  assign int_req_wr.aw        =  int_req.aw;
  assign int_req_wr.aw_valid  =  int_req.aw_valid;
  assign int_rsp.aw_ready     =  int_rsp_wr.aw_ready;
  /// Write W channel 
  assign int_req_wr.w         =  int_req.w;
  assign int_req_wr.w_valid   =  int_req.w_valid;
  assign int_rsp.w_ready      =  int_rsp_wr.w_ready;
  /// Write B channel 
  assign int_rsp.b            =  int_rsp_wr.b;
  assign int_rsp.b_valid      =  int_rsp_wr.b_valid;
  assign int_req_wr.b_ready   =  int_req.b_ready;
  /// Read AR channel 
  assign int_req_rd.ar        =  int_req.ar;
  assign int_req_rd.ar_valid  =  int_req.ar_valid;
  assign int_rsp.ar_ready     =  int_rsp_rd.ar_ready;
  /// Read R channel 
  assign int_rsp.r            =  int_rsp_rd.r;
  assign int_rsp.r_valid      =  int_rsp_rd.r_valid;
  assign int_req_rd.r_ready   =  int_req.r_ready;
  

  write_guard #(
    .MaxUniqIds ( MaxWrUniqIds ),
    .MaxWrTxns  ( MaxWrTxns    ), // total writes
    .CntWidth   ( CntWidth     ),
    .req_t      ( slv_req_t    ),
    .rsp_t      ( slv_rsp_t    ),
    .cnt_t      ( latency_t    ),
    .id_t       ( id_t         ),
    .aw_chan_t  ( aw_chan_t    ),
    .reg2hw_t   ( slv_guard_reg_pkg::slv_guard_reg2hw_t ),
    .hw2reg_t   ( slv_guard_reg_pkg::slv_guard_hw2reg_t )
  ) i_write_monitor_unit (
    .clk_i,
    .rst_ni,
    .guard_ena_i  ( guard_ena_i  ),
    .inp_req_i    ( wr_enqueue   ),

    .mst_req_i    ( int_req_wr   ),  
    .mst_rsp_o    ( int_rsp_wr   ),

    .slv_rsp_i    ( wr_rsp       ),
    .slv_req_o    ( wr_req       ),  

    .reset_req_o  ( rst_req_wr   ),
    .irq_o        ( write_irq    ),

    .reg2hw_i     ( reg2hw_w     ),
    .hw2reg_o     ( hw2reg_w     )
  );

  read_guard #(
    .MaxUniqIds ( MaxRdUniqIds ),
    .MaxRdTxns  ( MaxRdTxns    ), 
    .CntWidth   ( CntWidth     ),
    .req_t      ( slv_req_t    ),
    .rsp_t      ( slv_rsp_t    ),
    .cnt_t      ( latency_t    ),
    .id_t       ( id_t         ),
    .ar_chan_t  ( ar_chan_t    ),
    .reg2hw_t   ( slv_guard_reg_pkg::slv_guard_reg2hw_t ),
    .hw2reg_t   ( slv_guard_reg_pkg::slv_guard_hw2reg_t )
  ) i_read_monitor_unit (
    .clk_i,
    .rst_ni,
    .guard_ena_i  ( guard_ena_i  ),
    .inp_req_i    ( rd_enqueue   ),
    .mst_req_i    ( int_req_rd   ),  
    .mst_rsp_o    ( int_rsp_rd   ),
    .slv_rsp_i    ( rd_rsp       ),
    .slv_req_o    ( rd_req       ),                                                                                
    .reset_req_o  ( rst_req_rd   ),
    .irq_o        ( read_irq     ),
    .reg2hw_i     ( reg2hw_r     ),
    .hw2reg_o     ( hw2reg_r     )
  );
  
  assign req_oup.aw        =  wr_req.aw;
  assign req_oup.aw_valid  =  wr_req.aw_valid;
  assign wr_rsp.aw_ready   =  rsp_inp.aw_ready;

  assign req_oup.w         =  wr_req.w;
  assign req_oup.w_valid   =  wr_req.w_valid;
  assign wr_rsp.w_ready    =  rsp_inp.w_ready;

  assign req_oup.ar        =  rd_req.ar;
  assign req_oup.ar_valid  =  rd_req.ar_valid;
  assign rd_rsp.ar_ready   =  rsp_inp.ar_ready;

  assign wr_rsp.b          =  rsp_inp.b;
  assign wr_rsp.b_valid    =  rsp_inp.b_valid;
  assign req_oup.b_ready   =  wr_req.b_ready;
  
  assign rd_rsp.r          =  rsp_inp.r;
  assign rd_rsp.r_valid    =  rsp_inp.r_valid;
  assign req_oup.r_ready   =  rd_req.r_ready;
  
  assign rst_req_o = rst_req_wr | rst_req_rd;
  assign irq_o   =  read_irq  | write_irq;

endmodule: slv_guard_top