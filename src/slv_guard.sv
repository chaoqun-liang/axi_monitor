// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Thomas Benz <tbenz@iis.ee.ethz.ch>

/// Guards rogue subordinate units
module slv_guard (
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
    input  logic     clk_i,
    /// Asynchronous reset
    input  logic     rst_ni,
    /// Request from manager
    input  req_t     req_i,
    /// Response to manager
    output rsp_t     rsp_o,
    /// Request to subordinate
    output req_t     req_o,
    /// Response from subordinate
    input  rsp_t     rsp_i,
    /// Register bus request
    input  reg_req_t reg_req_i,
    /// Register bus response
    output reg_rsp_t reg_rsp_o,
    /// Interrupt line
    output logic     irq_o,
    /// Reset request
    output logic     rst_req_o,
    /// Reset status
    input  logic     rst_stat_i
    /// TBD: Reset configuration
);

endmodule
