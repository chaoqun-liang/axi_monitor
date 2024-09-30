/// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

module prescaler #(
  parameter int unsigned DivFactor = 1 
)(
    input logic clk_i, 
    input logic rst_ni,
    output logic prescaled_o
);

  logic [$clog2(DivFactor)-1 :0] counter;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      counter <= 0;
      prescaled_o <= 0;
    end else begin
      if (counter == ( DivFactor - 1)) begin
        counter <= 0;
        prescaled_o <= 1;
      end else begin 
        counter <= counter + 1;
        prescaled_o <= 0;
      end
    end
  end
endmodule