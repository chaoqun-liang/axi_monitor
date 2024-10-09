// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

module ld_free #(
  parameter int  unsigned MaxWrTxns = 16, // Define the capacity of the linked_data table
  parameter type linked_data_t      = logic
)(
  input  linked_data_t [MaxWrTxns-1:0] linked_data_q_i, 
  output logic [MaxWrTxns-1:0]         linked_data_free_o 
);

  generate
    for (genvar i = 0; i < MaxWrTxns; i++) begin: gen_linked_data_free
      assign linked_data_free_o[i] = linked_data_q_i[i].free;
    end
  endgenerate

endmodule
