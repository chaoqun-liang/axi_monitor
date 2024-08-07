/// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

module sticky_bit (
  input logic clk_i, 
  input logic rst_ni,
  input logic release_i,
  input logic sticky_i, 
  output logic sticky_o
);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sticky_o <= 0;
    end else if (sticky_i) begin
      sticky_o <= 1;
    end else if( release_i ) begin 
      sticky_o <= 0;
    end
  end 
endmodule