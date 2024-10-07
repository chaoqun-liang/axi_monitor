/// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

`include "axi/assign.svh"
`include "axi/typedef.svh"
`include "register_interface/typedef.svh"

import axi_pkg::*;
import slv_pkg::*;

 module monitor_wrap 
(
  /// Clock
  input  logic               clk_i,
  /// Asynchronous reset
  input  logic               rst_ni,
  /// Guard enable
  input  logic               guard_ena_i,
  /// Request from manager
  input  mst_req_t           req_i,
  /// Response to manager
  output mst_resp_t          rsp_o,
  /// Request to slave
  output slv_req_t           req_o,
  /// Response from slave
  input  slv_resp_t          rsp_i,
  /// Register bus request
  input  cfg_req_t           reg_req_i,
  /// Register bus response
  output cfg_rsp_t           reg_rsp_o,
  /// Interrupt line
  output logic               irq_o,
  /// Reset request
  output logic               rst_req_o,
  /// Reset status
  input  logic               rst_stat_i
  /// TBD: Reset configuration
);  

slv_guard_top #(
  .AddrWidth    ( AxiAddrWidth   ),
  .DataWidth    ( AxiDataWidth   ),
  .StrbWidth    ( AxiDataWidth/8 ),
  .AxiIdWidth   ( AxiIdWidth     ),
  .AxiUserWidth ( AxiUserWidth   ),
  .MaxTxnsPerId ( MaxTxnsPerId   ),
  .MaxUniqIds   ( MaxUniqIds     ),
  .CntWidth     ( CntWidth       ),
  .PrescalerDiv ( PrescalerDiv   ),
  .req_t        ( mst_req_t      ), 
  .rsp_t        ( mst_resp_t     ),
  .slv_req_t    ( slv_req_t      ),
  .slv_rsp_t    ( slv_resp_t     ),
  .reg_req_t    ( cfg_req_t      ), 
  .reg_rsp_t    ( cfg_rsp_t      )
) i_slv_guard (
  .clk_i      (clk_i),
  .rst_ni     (rst_ni),
  .guard_ena_i(guard_ena_i),
  .req_i      (req_i),
  .rsp_o      (rsp_o),
  .req_o      (req_o),
  .rsp_i      (rsp_i),
  .reg_req_i  (reg_req_i),
  .reg_rsp_o  (reg_rsp_o),
  .irq_o      (irq_o),
  .rst_req_o  (rst_req_o),
  .rst_stat_i (rst_stat_i)
);

endmodule: monitor_wrap