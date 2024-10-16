/// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
`include "axi/assign.svh"
`include "axi/typedef.svh"
`include "register_interface/typedef.svh"

package slv_pkg;

// Monitor parameters
  parameter int unsigned MaxUniqIds    = 32;
  parameter int unsigned MaxTxnsPerId  = 1; 
  parameter int unsigned CntWidth      = 10;
  parameter int unsigned PrescalerDiv  = 1;
  // AXI parameters
  parameter int unsigned AxiAddrWidth  = 48;
  parameter int unsigned AxiDataWidth  = 32;
  parameter int unsigned AxiIdWidth    = 6; 
  parameter int unsigned AxiIntIdWidth = (MaxUniqIds > 1) ? $clog2(MaxUniqIds) : 1;
  parameter int unsigned AxiUserWidth  = 1;
  parameter int unsigned AxiLogDepth   = 1;
  // Regbus parameters
  parameter int unsigned  RegAddrWidth = 32;
  parameter int unsigned  RegDataWidth = 32;
  
  // AXI type dependent parameters; do not override!
  parameter type addr_t   = logic [AxiAddrWidth-1:0];
  parameter type data_t   = logic [AxiDataWidth-1:0];
  parameter type strb_t   = logic [AxiDataWidth/8-1:0];
  parameter type id_t     = logic [AxiIdWidth-1:0];
  parameter type intid_t  = logic [AxiIntIdWidth-1:0];
  parameter type user_t   = logic [AxiUserWidth-1:0];

  //  reg type dependent parameters; do not override!
  parameter type reg_addr_t   = logic [RegAddrWidth-1:0];
  parameter type reg_data_t   = logic [RegDataWidth-1:0];
  parameter type reg_strb_t   = logic [RegDataWidth/8-1:0];

  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t);
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(r_chan_t, data_t, id_t, user_t);
  `AXI_TYPEDEF_REQ_T(mst_req_t, aw_chan_t, w_chan_t, ar_chan_t);
  `AXI_TYPEDEF_RESP_T(mst_resp_t, b_chan_t, r_chan_t );
  
  /// Intermediate AXI types
  `AXI_TYPEDEF_AW_CHAN_T(int_aw_t, addr_t, intid_t, user_t);
  `AXI_TYPEDEF_W_CHAN_T(w_t, data_t, strb_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(int_b_t, intid_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(int_ar_t, addr_t, intid_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(int_r_t, data_t, intid_t, user_t);
  `AXI_TYPEDEF_REQ_T(slv_req_t, int_aw_t, w_t, int_ar_t);
  `AXI_TYPEDEF_RESP_T(slv_resp_t, int_b_t, int_r_t );

  `REG_BUS_TYPEDEF_ALL(cfg, reg_addr_t, reg_data_t, reg_strb_t);

endpackage