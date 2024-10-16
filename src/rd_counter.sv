// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

module rd_counter #(
  parameter type linked_data_t    = logic,
  parameter int unsigned CntWidth = 2  // Define the width of the counter/data
) (
  input  logic         clk_i,           // Clock input
  input  logic         rst_ni,          // Asynchronous reset (active low)
  input  logic         prescaled_en,    // Enable for prescaler
  input  logic         r_valid_sticky,  // Sticky signal for valid
  input  logic         r_ready_sticky,  // Sticky signal for ready
  input  logic         r_last_sticky,
  input  linked_data_t linked_data_d_i, // Input data for the linked_data_q
  output linked_data_t linked_data_q_o  // Output data after processing
);

  // Internal register to hold the linked data
  linked_data_t linked_data_q;   // Register for linked data
  // Assign output
  assign linked_data_q_o = linked_data_q;

  // Always block for clocked process
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      linked_data_q <= '0;
      linked_data_q.free   <= 1'b1;
    end else begin
      // Normal operation, update linked_data_q and counter
      linked_data_q <= linked_data_d_i;
      // Only if this slot is in use (i.e., there is an outstanding transaction)
      if (!linked_data_q.free) begin  
        if (!(r_valid_sticky && r_last_sticky && r_ready_sticky) && prescaled_en) begin
          linked_data_q.counter <= linked_data_q.counter - 1; // Note: cannot do self-decrement due to buggy tool
        end
      end
    end
  end

endmodule
