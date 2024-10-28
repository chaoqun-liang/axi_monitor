// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
// - Chaoqun Liang <chaoqun.liang@unibo.it>

module rd_counter #(
  parameter int unsigned IdCapacity = 2,
  parameter type id_track_t         = logic,
  parameter type track_cnt_t        = logic,
  parameter type id_idx_t           = logic,
  parameter type id_t               = logic
) (
  input  logic                  clk_i,          
  input  logic                  rst_ni,         
  input  track_cnt_t            budget,
  input  logic                  prescaled_en,
  input  logic                  r_valid,         
  input  logic                  r_ready,
  input  logic                  r_last,
  input  id_t                   slv_rsp_id_i,
  input  logic [IdCapacity-1:0] idx_rsp_id,         
  input  id_track_t             id_track_d_i, 
  output id_track_t             id_track_q_o  
);
  id_track_t  id_track_q;  
  assign id_track_q_o = id_track_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      id_track_q <= '0;
      id_track_q.free   <= 1'b1;
      id_track_q.txn_budget <= budget;
    end else begin
      // Normal operation, update id_track and counter
      id_track_q <= id_track_d_i;
      // Only if this slot is in use (i.e., there is an outstanding transaction)
      if (!id_track_q.free) begin  
        if (!(r_valid && r_ready && r_last && (slv_rsp_id_i == id_track_q.id)) && prescaled_en) begin
          id_track_q.txn_budget <= id_track_q.txn_budget - 1; // Note: cannot do self-decrement due to buggy tool
        end 
      end
    end
  end

endmodule
