// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Thomas Benz <tbenz@iis.ee.ethz.ch>

/// Guards rogue subordinate units
`include "axi/typedef.svh"
`include "common_cells/registers.svh"

module slv_guard (
  /// Number of subordinates 
  parameter int unsigned NumSub = 1,
  /// ID remapper
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
  /// Subordinate request type
  parameter type req_t = logic, 
  /// Subordinate response type
  parameter type rsp_t = logic, 
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
  output req_t [NumSub-1:0] req_o,
  /// Response from subordinate
  input  rsp_t [NumSub-1:0] rsp_i,
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
  slv_guard_reg_pkg::slv_guard_reg2hw_t reg2hw;
  slv_guard_reg_pkg::slv_guard_hw2reg_t hw2reg;

  slv_guard_reg_top #(
    .reg_req_t(reg_req_t),
    .reg_rsp_t(reg_rsp_t),
  ) i_regs (
    .clk_i,
    .rst_ni,
    .reg_req_i ( reg_req_i    ),
    .reg_rsp_o ( reg_rsp_o    ),
    .reg2hw    ( reg2hw       ), 
    .hw2reg    ( hw2reg       ),  
    .devmode_i ( 1'b1         )
  );
  

  logic enqueue;
  assign enqueue = req_i.aw_valid;
  localparam int unsigned AddrWidth  = $bits(req_i.aw.addr);
  localparam int unsigned DataWidth  = $bits(req_i.w.data);
  localparam int unsigned StrbWidth  = DataWidth/8;
  localparam int unsigned UserWidth  = $bits(req_i.aw.user);
  localparam int unsigned AxiIdWidth = $bits(req_i.aw.id); 
  /// Q: it gives the mimimum internal id width here. or should i leave this decision to the users? 
  localparam int unsigned IntIdWidth = cf_math_pkg::idx_width(MaxUniqIds);

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [StrbWidth-1:0] strb_t;
  typedef logic [AxiIdWidth-1:0] id_t;
  typedef logic [IntIdWidth-1:0] int_id_t;
  typedef logic [UserWidth-1:0] user_t;

  /// AXI types
  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t);
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
  `AXI_TYPEDEF_REQ_T(int_req_t, int_aw_t, w_t, int_ar_t);
  `AXI_TYPEDEF_RESP_T(int_rsp_t, int_b_t, int_r_t );

  assign idma_reg_req.opt.beo.dst_max_llen       = reg2hw.beo.dst_max_llen.q;
  assign idma_reg_req.opt.beo.src_reduce_len     = reg2hw.beo.src_reduce_len.q;
  assign idma_reg_req.opt.beo.dst_reduce_len     = reg2hw.beo.dst_reduce_len.q;

  assign idma_reg_req.opt.last                   = reg2hw.last.q;

  assign idma_req_valid                          = reg2hw.req_valid.q;
  assign idma_rsp_ready                          = reg2hw.rsp_ready.q;

  /// Intermediate AXI channel
  int_req_t [NumSub-1:0] int_req;
  int_rsp_t [NumSub-1:0] int_rsp;
  
  // counter typedef
  typedef logic [CntWidth-1:0] latency_t;
  typedef logic [IntIdWidth-1:0] id_t;

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
    .slv_req_t            ( req_t         )
    .slv_resp_t           ( rsp_t         )
    .mst_req_t            ( int_req_t     )
    .mst_resp_t           ( int_rsp_t     )
  ) i_axi_id_remap (
    .clk_i,
    .rst_ni,
    .slv_req_i  ( req_i    ),
    .slv_resp_o ( rsp_o    ),
    .mst_req_o  ( int_req  ),
    .mst_resp_i ( int_rsp  )
  );
   
  /// AXI Write transactions monitoring unit 
  write_guard #(
    .MaxUniqIds ( MaxWrUniqIds ),
    .MaxWrTxns  ( MaxWrTxns    ), // total writes
    .CntWidth   ( CntWidth     ),
    .req_t      ( req_t        ),
    .rsp_t      ( rsp_t        ),
    .cnt_t      ( latency_t    ),
    .id_t       ( id_t         ),
    .reg2hw_t   ( slv_guard_reg2hw_t ),
    .hw2reg_t   ( slv_guard_hw2reg_t ),
  ) i_write_monitor_unit (
    .clk_i,
    .rst_ni,
    .guard_ena_i  ( guard_ena_i),
  
    .mst_req_i    (  req_i   ),  
    .mst_rsp_o    (  rsp_o   ),
    .slv_rsp_i    (  rsp_i   ),
    .slv_req_o    (  req_o   ), 
  
    .inp_req_i    (  enqueue ), 
    .inp_gnt_o    (  ),
                                                                                                                                      
    .oup_data_valid_o,
    .oup_gnt_o,

    .reset_req_o  ( rst_req_o ),
    .irq_o        ( irq_o     ),

    .reg2hw_i     ( reg2hw    ),
    .hw2reg_o     ( hw2reg    ),
    .budget_awvld_awrdy_i( budget_awvld_awrdy ),
    .budget_awvld_wvld_i ( budget_awvld_wvld  ),
    .budget_wvld_wrdy_i  ( budget_wvld_wrdy   ),
    .budget_wvld_wlast_i ( budget_wvld_wlast  ),
    .budget_wlast_bvld_i ( budget_wlast_bvld  ),
    .budget_wlast_brdy_i ( budget_wlast_brdy  )
  );


assign irq_o = submod1_irq | submod2_irq; // both read and write 

endmodule