`include "axi/assign.svh"
`include "axi/typedef.svh"
`include "register_interface/typedef.svh"

package slv_pkg;

// Monitor parameters
  parameter int unsigned MaxUniqIds    = 2;
  parameter int unsigned MaxTxnsPerId  = 4; 
  parameter int unsigned CntWidth      = 10;
  parameter int unsigned PrescalerDiv  = 64;
  // AXI parameters
  parameter int unsigned AxiAddrWidth  = 48;
  parameter int unsigned AxiDataWidth  = 64;
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

  `AXI_TYPEDEF_ALL(mst, addr_t, id_t, data_t, strb_t, user_t);
  `AXI_TYPEDEF_ALL(slv, addr_t, intid_t, data_t, strb_t, user_t);
  `REG_BUS_TYPEDEF_ALL(cfg, reg_addr_t, reg_data_t, reg_strb_t);

endpackage