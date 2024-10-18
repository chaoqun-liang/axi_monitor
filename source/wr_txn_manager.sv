// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

// Authors:
// - Chaoqun Liang <chaoqun.liang@unibo.it>

module wr_txn_manager #(
  parameter int  unsigned IdCapacity = 1,
  parameter type id_track_t     = logic,
  parameter type id_idx_t       = logic,
  parameter type track_cnt_t    = logic,
  parameter type req_t          = logic,
  parameter type rsp_t          = logic,
  parameter type id_t           = logic,
  parameter type hw2reg_t       = logic,
  parameter type reg2hw_t       = logic
)(
  input  logic                          wr_en_i,
  input  logic                          full_i,
  input  track_cnt_t                    txn_budget,
  input  logic                          id_exists_i,
  input  id_idx_t                       rsp_idx_i,
  input  req_t                          mst_req_i,
  input  rsp_t                          slv_rsp_i,
  input  logic                          no_in_id_match_i,
  input  id_idx_t                       id_table_free_idx_i,
  input  id_idx_t                       match_in_idx_i,
  output logic                          timeout,
  output logic                          reset_req,
  output logic                          oup_req,
  output id_t                           oup_id,
  output id_t                           match_in_id,
  output logic                          match_in_id_valid, 
  input  id_track_t [IdCapacity-1:0]    id_track_q,
  output id_track_t [IdCapacity-1:0]    id_track_d,
  output hw2reg_t                       hw2reg_o,
  input  reg2hw_t                       reg2hw_i
);
  
  // Transaction states handling
  always_comb begin
    match_in_id         = '0;
    match_in_id_valid   = 1'b0;
    id_track_d          = id_track_q;
    oup_id              = '0;
    oup_req             = 1'b0;
    timeout             = 1'b0;
    reset_req           = 1'b0;
    hw2reg_o.irq.unwanted_wr_resp.d = reg2hw_i.irq.unwanted_wr_resp.q;
    hw2reg_o.irq.txn_id.d       = reg2hw_i.irq.txn_id.q;
    hw2reg_o.irq.wr_timeout.d   = reg2hw_i.irq.wr_timeout.q;
    hw2reg_o.irq.irq.d          = reg2hw_i.irq.irq.q;
    hw2reg_o.irq_addr.d         = reg2hw_i.irq_addr.q;
    hw2reg_o.reset.d            = reg2hw_i.reset.q;
    hw2reg_o.latency_write.d    = reg2hw_i.latency_write.q;

    // Transaction states handling
    for ( int i = 0; i < IdCapacity; i++ ) begin : proc_wr_txn_states
      if (!id_track_q[i].free ) begin 
        if (id_track_q[i].txn_budget == 0 ) begin 
          timeout = 1'b1;
          hw2reg_o.irq.wr_timeout.d = 1'b1;
          reset_req = 1'b1;
          hw2reg_o.reset.d = 1'b1;
          hw2reg_o.irq.txn_id.d = id_track_q[i].id;
          hw2reg_o.irq.irq.d = 1'b1;
        end
      end
    end

    if( slv_rsp_i.b_valid && mst_req_i.b_ready && !timeout ) begin 
      if( id_exists_i ) begin
        oup_req = 1; 
        oup_id = slv_rsp_i.b.id; // Just use transaction ID
        //hw2reg_o.latency_write.d = linked_data_q[head_tail_q[rsp_idx_i].head].counter;
      end else begin 
        hw2reg_o.irq.unwanted_wr_resp.d = 1'b1;
        hw2reg_o.reset.d = 1'b1;
        reset_req = 1'b1;
        hw2reg_o.irq.irq.d = 1'b1;
      end
    end
    
    // Enqueue
    if (wr_en_i && !full_i) begin : proc_txn_enqueue
      match_in_id = mst_req_i.aw.id;
      match_in_id_valid = 1'b1;  
      if (no_in_id_match_i) begin
        id_track_d[id_table_free_idx_i] = '{
          id: mst_req_i.aw.id,
          num_txn: 1,
          txn_budget: txn_budget,
          free: (id_track_d[match_in_idx_i].num_txn < 32) ? 1'b1 : 1'b0
        };
      end else begin
        id_track_d[match_in_idx_i].num_txn = id_track_q[match_in_idx_i].num_txn + 1;
        id_track_d[match_in_idx_i].free    = (id_track_d[match_in_idx_i].num_txn < 32) ? 1'b1 : 1'b0;
      end
    end

    // Dequeue 
    if (oup_req) begin : proc_txn_dequeue // Same as id_exists_i
      // If it is the last cell of this ID
      id_track_d[rsp_idx_i].num_txn = id_track_q[rsp_idx_i].num_txn - 1;
      if (id_track_q[rsp_idx_i].num_txn == 1) begin
        //id_track_d[rsp_idx_i] = '{free: 1'b1, default: '0};
        id_track_d[rsp_idx_i]           = '0;
        id_track_d[rsp_idx_i].free      = (id_track_d[rsp_idx_i].num_txn < 32) ? 1'b1 : 1'b0;
      end
    end

    if (reset_req) begin
      for (int i = 0; i < IdCapacity; i++) begin
        id_track_d[i]           = '0;
        id_track_d[i].free      = 1'b1;
      end
    end
  end

endmodule