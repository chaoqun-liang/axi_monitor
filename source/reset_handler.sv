// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

module reset_handler (
  input  logic clk_i,            // Clock input
  input  logic rst_ni,           // Asynchronous reset (active low)
  input  logic reset_req_i,        // Reset request signal
  input  logic reset_clear_i,    // Reset clear signal
  output logic reset_req_q_o,      // Latched reset request output
  output logic irq_o               // Interrupt request signal
);

  // Always block for clocked process
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      reset_req_q_o <= 1'b0;
      irq_o <= 1'b0;
    end else begin
      // Latch reset request
      if (reset_req_i) begin
        reset_req_q_o <= 1'b1;
        irq_o <= 1'b1;
      end else if (reset_clear_i) begin
        reset_req_q_o <= 1'b0;
      end
    end
  end

endmodule
