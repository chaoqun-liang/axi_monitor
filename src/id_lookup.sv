// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

module id_lookup #(
    parameter type id_t = logic,
    parameter type head_tail_t = logic
) (
    input  logic                  match_in_id_valid,
    input  id_t                   match_in_id,
    input  id_t                   rsp_id,
    input  head_tail_t            head_tail_q_i,
    output logic                  idx_matches_in_id_o,
    output logic                  idx_rsp_id_o
);
  // Logic for idx_matches_in_id
  assign idx_matches_in_id_o = match_in_id_valid &&
                                 (head_tail_q_i.id == match_in_id) &&
                                 !head_tail_q_i.free;

  // Logic for idx_rsp_id
  assign idx_rsp_id_o = (head_tail_q_i.id == rsp_id) &&
                          !head_tail_q_i.free;

endmodule