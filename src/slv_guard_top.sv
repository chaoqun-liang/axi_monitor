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
  /// Number of subordinates 
  parameter int unsigned NumSub = 1,
  parameter int unsigned AddrWidth = 0,
  parameter int unsigned DataWidth = 0,
  parameter int unsigned StrbWidth = 0,
  parameter int unsigned AxiIdWidth = 0,
  parameter int unsigned AxiUserWidth = 0,
  /// ID remapper
  parameter int unsigned MaxUniqIds   = 4,
  parameter int unsigned MaxTxnsPerId = 4, 
  /// Write transaction unique IDs
  parameter int unsigned MaxWrUniqIds = 4,
  /// Read transaction unique IDs
  parameter int unsigned MaxRdUniqIds = 4,
  /// Maximum number outstanding write transactions 
  parameter int unsigned MaxWrTxns = 4,
  /// Maximum number outstanding read transactions 
  parameter int unsigned MaxRdTxns  = 4,
  /// Counter width
  parameter int unsigned CntWidth = 0,
  /// Internal ID width
  parameter int unsigned IntIdWidth = 2, 
  /// Subordinate request type
  parameter type req_t = logic, 
  /// Subordinate response type
  parameter type rsp_t = logic, 
  /// Subordinate request type op
  parameter type slv_req_t = logic, 
  /// Subordinate response type op
  parameter type slv_rsp_t = logic, 
  /// Configuration register bus request type
  parameter type reg_req_t = logic,
  /// Configuration register bus response type
  parameter type reg_rsp_t = logic
)(
  /// Clock
  input  logic              clk_i,
  /// Asynchronous reset
  input  logic              rst_ni,
  /// Guard enable
  input  logic              guard_ena_i,
  /// Request from manager
  input  req_t [NumSub-1:0] req_i,
  /// Response to manager
  output rsp_t [NumSub-1:0] rsp_o,
  /// Request to subordinate
  output slv_req_t [NumSub-1:0] req_o,
  /// Response from subordinate
  input  slv_rsp_t [NumSub-1:0] rsp_i,
  /// Register bus request
  input  reg_req_t          reg_req_i,
  /// Register bus response
  output reg_rsp_t          reg_rsp_o,
  /// Interrupt line
  output logic              irq_o,
  /// Reset request
  output logic [NumSub-1:0] rst_req_o,
  /// Reset status
  input  logic [NumSub-1:0] rst_stat_i
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

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [StrbWidth-1:0] strb_t;
  typedef logic [AxiIdWidth-1:0] id_t;
  typedef logic [IntIdWidth-1:0] int_id_t;
  typedef logic [AxiUserWidth-1:0] user_t;

  /// AXI types
  //`AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t);
  //`define AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t)  
  typedef struct packed {                                       
    id_t              id;                                       
    addr_t            addr;                                     
    axi_pkg::len_t    len;                                      
    axi_pkg::size_t   size;                                     
    axi_pkg::burst_t  burst;                                    
    logic             lock;                                     
    axi_pkg::cache_t  cache;                                    
    axi_pkg::prot_t   prot;                                     
    axi_pkg::qos_t    qos;                                      
    axi_pkg::region_t region;                                   
    axi_pkg::atop_t   atop;                                     
    user_t            user;                                     
  } aw_chan_t;
  // `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t);
  // `AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t);
  // `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t);
  // `AXI_TYPEDEF_R_CHAN_T(r_chan_t, data_t, id_t, user_t);
  // `AXI_TYPEDEF_REQ_T(axi_req_t, aw_chan_t, w_chan_t, ar_chan_t);
  // `AXI_TYPEDEF_RESP_T(axi_rsp_t, b_chan_t, r_chan_t );

  /// Intermediate AXI types
  `AXI_TYPEDEF_AW_CHAN_T(int_aw_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_W_CHAN_T(w_t, data_t, strb_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(int_b_t, int_id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(int_ar_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(int_r_t, data_t, int_id_t, user_t);
  `AXI_TYPEDEF_REQ_T(internal_req_t, int_aw_t, w_t, int_ar_t);
  `AXI_TYPEDEF_RESP_T(internal_rsp_t, int_b_t, int_r_t );

  /// Intermediate AXI channel
  internal_req_t  int_req, int_req_wr, int_req_rd, wr_req_o, rd_req_o;
  internal_rsp_t  int_rsp, rd_rsp, wr_rsp, int_rsp_wr, int_rsp_rd;

  // counter typedef
  typedef logic [CntWidth-1:0] latency_t;

  latency_t   budget_awvld_awrdy;
  latency_t   budget_awvld_wvld;
  latency_t   budget_wvld_wrdy;
  latency_t   budget_wvld_wlast;
  latency_t   budget_wlast_bvld;
  latency_t   budget_wlast_brdy;

  // latency_t   budget_arvld_arrdy;
  // latency_t   budget_arvld_rvld;
  // latency_t   budget_rvld_rrdy;
  // latency_t   budget_rvld_rlast;

  assign  budget_awvld_awrdy      = reg2hw.budget_awvld_awrdy.q;
  assign  budget_awvld_wvld       = reg2hw.budget_awvld_wfirst.q;
  assign  budget_wvld_wrdy        = reg2hw.budget_wvld_wrdy.q;
  assign  budget_wvld_wlast       = reg2hw.budget_wvld_wlast.q;
  assign  budget_wlast_bvld       = reg2hw.budget_wlast_bvld.q;
  assign  budget_wlast_brdy       = reg2hw.budget_wlast_brdy.q;

  // assign  budget_arvld_arrdy      = reg2hw.budget_arvld_arrdy.q;
  // assign  budget_arvld_rvld       = reg2hw.budget_arvld_rvld.q;
  // assign  budget_rvld_rrdy        = reg2hw.budget_rvld_rrdy.q;
  // assign  budget_rvld_rlast       = reg2hw.budget_rvld_rlast.q; 

  /// Remap wider ID to narrower ID
  axi_id_remap #(
    .AxiSlvPortIdWidth    ( AxiIdWidth    ),
    .AxiSlvPortMaxUniqIds ( MaxUniqIds    ),
    .AxiMaxTxnsPerId      ( MaxTxnsPerId  ),
    .AxiMstPortIdWidth    ( IntIdWidth    ),
    .slv_req_t            ( req_t         ),
    .slv_resp_t           ( rsp_t         ),
    .mst_req_t            ( internal_req_t     ),
    .mst_resp_t           ( internal_rsp_t     )
  ) i_axi_id_remap (
    .clk_i,
    .rst_ni,
    .slv_req_i  ( req_i    ),
    .slv_resp_o ( rsp_o    ),
    .mst_req_o  ( int_req  ),
    .mst_resp_i ( int_rsp  )
  );

  logic  write_req, read_req;
  logic  write_irq, read_irq;
  logic rst_req_wr, rst_req_rd;
  assign write_req = int_req.aw_valid;
  assign read_req = int_req.ar_valid;
  internal_rsp_t slv_rsp;
  assign  slv_rsp = rsp_i;
  
  always_comb begin
    int_req_wr = '0;
    int_req_rd = '0;
    int_rsp = '0;
    rd_rsp = '0;
    wr_rsp = '0;
    req_o = '0;

    if (int_req.aw_valid) begin
      int_req_wr = int_req;
    end else if (int_req.ar_valid) begin
      int_req_rd = int_req;
    end

    if (int_rsp_rd.ar_ready) begin
      int_rsp = int_rsp_rd;
    end else if (int_rsp_wr.aw_ready) begin
      int_rsp = int_rsp_wr;
    end 

    if (slv_rsp.ar_ready) begin
      rd_rsp = slv_rsp;
    end else if (slv_rsp.aw_ready) begin
      wr_rsp = slv_rsp;
    end
    // slv type wrong

    if (wr_req_o.aw_valid) begin
      req_o = wr_req_o;
    end else if (rd_req_o.ar_valid) begin
      req_o = rd_req_o;
    end

  end

  write_guard #(
    .MaxUniqIds ( MaxWrUniqIds ),
    .MaxWrTxns  ( MaxWrTxns    ), // total writes
    .CntWidth   ( CntWidth     ),
    .req_t      ( req_t        ),
    .rsp_t      ( rsp_t        ),
    .cnt_t      ( latency_t    ),
    .id_t       ( id_t         ),
    .aw_chan_t  ( aw_chan_t    ),
    .reg2hw_t   ( slv_guard_reg_pkg::slv_guard_reg2hw_t ),
    .hw2reg_t   ( slv_guard_reg_pkg::slv_guard_hw2reg_t )
  ) i_write_monitor_unit (
    .clk_i,
    .rst_ni,
    .guard_ena_i  ( guard_ena_i  ),
    .inp_req_i    ( write_req    ),
    .mst_req_i    ( int_req_wr   ),  
    .mst_rsp_o    ( int_req_wr   ),
    .slv_rsp_i    ( wr_rsp       ),
    .slv_req_o    ( wr_req_o     ),                                                                                
    .reset_req_o  ( rst_req_wr      ),
    .irq_o        ( write_irq    ),
    .reg2hw_i     ( reg2hw_w     ),
    .hw2reg_o     ( hw2reg_w     )
  );

  read_guard #(
    .MaxUniqIds ( MaxRdUniqIds ),
    .MaxRdTxns  ( MaxRdTxns    ), 
    .CntWidth   ( CntWidth     ),
    .req_t      ( req_t        ),
    .rsp_t      ( rsp_t        ),
    .cnt_t      ( latency_t    ),
    .id_t       ( id_t         ),
    .aw_chan_t  ( aw_chan_t    ),
    .reg2hw_t   ( slv_guard_reg_pkg::slv_guard_reg2hw_t ),
    .hw2reg_t   ( slv_guard_reg_pkg::slv_guard_hw2reg_t )
  ) i_read_monitor_unit (
    .clk_i,
    .rst_ni,
    .guard_ena_i  ( guard_ena_i  ),
    .inp_req_i    ( read_req     ),
    .mst_req_i    ( int_req_rd   ),  
    .mst_rsp_o    ( int_rsp_rd   ),
    .slv_rsp_i    ( rd_rsp       ),
    .slv_req_o    ( rd_req_o     ),                                                                                
    .reset_req_o  ( rst_req_rd   ),
    .irq_o        ( read_irq     ),
    .reg2hw_i     ( reg2hw_r     ),
    .hw2reg_o     ( hw2reg_r     )
  );
  
  assign rst_req_o = rst_req_wr | rst_req_rd;

endmodule: slv_guard_top