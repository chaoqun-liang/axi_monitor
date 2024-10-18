// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

module id_free #(
  parameter int unsigned IdCapacity = 16, // Define the capacity of the head-tail table
  parameter type id_track_t        = logic
)(
  input  id_track_t [IdCapacity-1:0] id_track_q, // Array of free signals from head-tail entries
  output logic [IdCapacity-1:0]   id_free_o // Array to indicate free entries
);

  // Generate loop to assign each head_tail_free entry based on head_tail_q
  generate
    for (genvar i = 0; i < IdCapacity; i++) begin: gen_id_free
      assign id_free_o[i] = id_track_q[i].free;
    end
  endgenerate

endmodule