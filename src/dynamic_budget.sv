// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

module dynamic_budget #(
  parameter int  MaxWrTxns    = 8,     // Maximum number of transactions
  parameter int  PrescalerDiv = 2,     // Prescaler divisor
  parameter type accu_cnt_t    = logic,
  parameter type linked_data_t = logic
) (
  input  linked_data_t [MaxWrTxns-1:0]     linked_data_q_i,
  output accu_cnt_t                        accum_burst_len // Total accumulated burst length
);
// Internal variable for the accumulated burst length
  accu_cnt_t temp_accum_len;

  always_comb begin
    temp_accum_len = 0;
    for (int i = 0; i < MaxWrTxns; i++) begin
      if (!linked_data_q_i[i].free) begin
        temp_accum_len += (((linked_data_q_i[i] + 1) >> $clog2(PrescalerDiv)) + 1);
      end
    end
  end

  // Assign the accumulated length to the output
  assign accum_burst_len = temp_accum_len;

endmodule
