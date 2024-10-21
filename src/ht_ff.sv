// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

module ht_ff #(
  parameter type head_tail_t = logic
) (
  input  logic                      clk_i,
  input  logic                      rst_ni,
  input  head_tail_t                head_tail_d_i,
  output head_tail_t                head_tail_q_o
);
  head_tail_t head_tail_q;
  assign head_tail_q_o = head_tail_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      head_tail_q <= '{free: 1'b1, default: '0};
    end else begin
      head_tail_q <= head_tail_d_i;
    end
  end

endmodule