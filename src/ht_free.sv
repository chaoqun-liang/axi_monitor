// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

module ht_free #(
  parameter int unsigned HtCapacity = 16, // Define the capacity of the head-tail table
  parameter type head_tail_t        = logic
)(
  input  head_tail_t [HtCapacity-1:0] head_tail_q, // Array of free signals from head-tail entries
  output logic [HtCapacity-1:0]   head_tail_free_o // Array to indicate free entries
);

  // Generate loop to assign each head_tail_free entry based on head_tail_q
  generate
    for (genvar i = 0; i < HtCapacity; i++) begin: gen_head_tail_free
      assign head_tail_free_o[i] = head_tail_q[i].free;
    end
  endgenerate

endmodule