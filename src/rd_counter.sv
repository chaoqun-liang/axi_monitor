// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

module rd_counter #(
  parameter int unsigned CntWidth = 2,
  parameter type linked_data_t    = logic,
  parameter type id_t             = logic,
  parameter type head_tail_t      = logic
) (
  input  logic         clk_i,           // Clock input
  input  logic         rst_ni,          // Asynchronous reset (active low)
  input  int unsigned  i,
  input  id_t          slv_b_id_i,
  input  logic         r_valid_i,
  input  logic         r_ready_i, 
  input  logic         r_last_i,
  input  head_tail_t   head_tail_q_i,
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
        if (!(r_valid_i && r_last_i && r_ready_i && ( i == head_tail_q_i.head ))) begin
          linked_data_q.counter <= linked_data_q.counter - 1; // Note: cannot do self-decrement due to buggy tool
        end
      end
    end
  end

endmodule