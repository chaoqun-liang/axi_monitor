// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
// - Chaoqun Liang <chaoqun.liang@unibo.it>

module wr_counter #(
  parameter int unsigned IdCapacity = 2,
  parameter type id_track_t         = logic,
  parameter type track_cnt_t        = logic,
  parameter type id_idx_t           = logic,
  parameter type id_t               = logic
) (
  input  logic                  clk_i,          
  input  logic                  rst_ni,         
  input  track_cnt_t            budget,
  input  logic                  b_valid,         
  input  logic                  b_ready,
  input  id_t                   slv_rsp_id_i,
  input  logic [IdCapacity-1:0] idx_rsp_id,                
  input  id_track_t             id_track_d_i, 
  output id_track_t             id_track_q_o  
); 
  id_track_t id_track_q;  
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
        if (!(b_valid && b_ready && (slv_rsp_id_i == id_track_q.id))) begin
          // all others without a matching id should 
          //id_track_q.num_txn <= id_track_q.num_txn - 1;
          //id_track_q.txn_budget <= budget;
        //end else begin
        id_track_q.txn_budget <= id_track_q.txn_budget - 1; // Note: cannot do self-decrement due to buggy tool
        end 
      end
    end
  end

endmodule
