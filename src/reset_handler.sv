// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

module reset_handler #(
  parameter int unsigned  PtrWidth = 1
)(
  input  logic                clk_i,            // Clock input
  input  logic                rst_ni,           // Asynchronous reset (active low)
  input  logic                reset_req_i,      // Reset request signal
  input  logic                reset_clear_i,    // Reset clear signal
  output logic                reset_req_q_o,    // Latched reset request output
  output logic                irq_o,  
  input  logic                timeout_i,
  output logic                timeout_q_o,
  input  logic [PtrWidth-1:0] wr_ptr_d_i,
  input  logic [PtrWidth-1:0] rd_ptr_d_i,
  input  logic                fifo_empty_d_i,
  input  logic                fifo_full_d_i,
  output logic [PtrWidth-1:0] wr_ptr_q_o,
  output logic [PtrWidth-1:0] rd_ptr_q_o,
  output logic                fifo_empty_q_o,
  output logic                fifo_full_q_o
);

  // Always block for clocked process
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      reset_req_q_o  <= 1'b0;
      irq_o          <= 1'b0;
      wr_ptr_q_o     <= 1'b0;
      rd_ptr_q_o     <= 1'b0;
      fifo_full_q_o  <= 1'b0;
      fifo_empty_q_o <= 1'b0;
      timeout_q_o    <= 1'b0;
    end else begin
      wr_ptr_q_o <= wr_ptr_d_i;
      rd_ptr_q_o <= rd_ptr_d_i;
      fifo_empty_q_o <= fifo_empty_d_i;
      fifo_full_q_o <= fifo_full_d_i;
      timeout_q_o  <=  timeout_i;
      // Latch reset request
      if (reset_req_i | timeout_i) begin
        reset_req_q_o <= 1'b1;
        irq_o <= 1'b1;
      end else if (reset_clear_i) begin
        reset_req_q_o <= 1'b0;
      end
    end
  end

endmodule