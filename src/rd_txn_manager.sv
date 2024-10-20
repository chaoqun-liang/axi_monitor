// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

// Authors:
// - Chaoqun Liang <chaoqun.liang@unibo.it>

module rd_txn_manager #(
  parameter int unsigned MaxRdTxns  = 1,
  parameter int unsigned HtCapacity = 1,
  parameter int unsigned PrescalerDiv = 1,
  parameter type linked_data_t  = logic,
  parameter type head_tail_t    = logic,
  parameter type ht_idx_t       = logic,
  parameter type ld_idx_t       = logic,
  parameter type req_t          = logic,
  parameter type rsp_t          = logic,
  parameter type id_t           = logic,
  parameter type accu_cnt_t     = logic,
  parameter type hw2reg_t       = logic,
  parameter type reg2hw_t       = logic
)(
  input  logic                          rd_en_i,
  input  logic                          wr_rst_i,
  input  logic                          full_i,
  input  logic [1:0]                    budget_read,
  input  accu_cnt_t                     accum_burst_length,
  input  logic                          id_exists_i,
  input  ht_idx_t                       rsp_idx_i,
  input  req_t                          mst_req_i,
  input  rsp_t                          slv_rsp_i,
  input  logic                          no_in_id_match_i,
  input  ht_idx_t                       head_tail_free_idx_i,
  input  ht_idx_t                       match_in_idx_i,
  input  ld_idx_t                       linked_data_free_idx_i,
  output logic                          timeout,
  output logic                          reset_req,
  output logic                          oup_req,
  output id_t                           oup_id,
  output id_t                           match_in_id,
  output logic                          match_in_id_valid, 
  output logic                          oup_data_valid,
  output logic                          oup_data_popped,
  output logic                          oup_ht_popped,
  input  head_tail_t [HtCapacity-1:0]   head_tail_q,
  output head_tail_t [HtCapacity-1:0]   head_tail_d,
  input  linked_data_t [MaxRdTxns-1:0]  linked_data_q,
  output linked_data_t [MaxRdTxns-1:0]  linked_data_d,
  output hw2reg_t                       hw2reg_o,
  input  reg2hw_t                       reg2hw_i
);

accu_cnt_t txn_budget; 

always_comb begin : proc_rd_queue
    match_in_id         = '0;
    match_in_id_valid   = 1'b0;
    head_tail_d         = head_tail_q;
    linked_data_d       = linked_data_q;
    oup_data_valid      = 1'b0;
    oup_data_popped     = 1'b0;
    oup_ht_popped       = 1'b0;
    oup_id              = 1'b0;
    oup_req             = 1'b0;
    timeout             = 1'b0;
    reset_req           = 1'b0;
    txn_budget          = '0;
    hw2reg_o.irq.unwanted_rd_resp.de = 1'b1;
    hw2reg_o.irq.irq.de              = 1'b1;
    hw2reg_o.irq.rd_timeout.de       = 1'b1;
    hw2reg_o.irq.txn_id.de           = 1'b1;
    hw2reg_o.irq_addr.de             = 1'b1;
    hw2reg_o.reset.de                = 1'b1;
    hw2reg_o.latency_read.de         = 1'b1;
    hw2reg_o.irq.unwanted_rd_resp.d  = '0;
    hw2reg_o.irq.irq.d               = '0;
    hw2reg_o.irq.rd_timeout.d        = '0;
    hw2reg_o.irq.txn_id.d            = '0;
    hw2reg_o.irq_addr.d              = '0;
    hw2reg_o.reset.d                 = '0;
    hw2reg_o.latency_read.d          = '0;
    
    // Transaction states handling
    for ( int i = 0; i < MaxRdTxns; i++ ) begin : proc_rd_txn_states
      if (!linked_data_q[i].free) begin 
        if (linked_data_q[i].counter == 0) begin 
          timeout = 1'b1;
          hw2reg_o.irq.rd_timeout.d = 1'b1;
          reset_req = 1'b1;
          hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id;
          hw2reg_o.reset.d = 1'b1;
          hw2reg_o.irq.irq.d = 1'b1;
        end
      end 
    end
    
    // check transaction completion
    if ( slv_rsp_i.r.last && slv_rsp_i.r_valid && mst_req_i.r_ready && !timeout ) begin
      if( id_exists_i ) begin
        oup_req = 1; 
        oup_id = slv_rsp_i.r.id;
        hw2reg_o.latency_read.d = linked_data_q[head_tail_q[rsp_idx_i].head].counter;
      end else begin 
        hw2reg_o.irq.unwanted_rd_resp.d = 'b1;
        hw2reg_o.reset.d = 1'b1;
        reset_req = 1'b1;
        hw2reg_o.irq.irq.d = 1'b1;
      end
    end
        
    // Enqueue
    if (rd_en_i && !full_i) begin : proc_txn_enqueue
      match_in_id = mst_req_i.ar.id;
      match_in_id_valid = 1'b1;  
      txn_budget = accum_burst_length + ((mst_req_i.ar.len) >> $clog2(PrescalerDiv)) + 2;
      if (no_in_id_match_i) begin
        head_tail_d[head_tail_free_idx_i] = '{
          id: mst_req_i.ar.id,
          head: linked_data_free_idx_i,
          tail: linked_data_free_idx_i,
          free: 1'b0
        };
      end else begin 
        linked_data_d[head_tail_q[match_in_idx_i].tail].next = linked_data_free_idx_i;
        head_tail_d[match_in_idx_i].tail = linked_data_free_idx_i;
      end
      linked_data_d[linked_data_free_idx_i] = '{
        metadata: '{id: mst_req_i.ar.id, len: mst_req_i.ar.len},
        counter: txn_budget,
        next: '0,
        free: 1'b0
      };
    end
    
    // Dequeue 
    if (oup_req) begin : proc_txn_dequeue
      oup_data_valid = 1'b1;
      oup_data_popped = 1;
      // Set free bit of linked data entry, all other bits are don't care.
      linked_data_d[head_tail_q[rsp_idx_i].head]          = '0;
      linked_data_d[head_tail_q[rsp_idx_i].head].free     = 1'b1;
      // If it is the last cell of this ID
      if (head_tail_q[rsp_idx_i].head == head_tail_q[rsp_idx_i].tail) begin
        oup_ht_popped = 1'b1;
        head_tail_d[rsp_idx_i] = '{free: 1'b1, default: '0};
      end else begin
        head_tail_d[rsp_idx_i].head = linked_data_q[head_tail_q[rsp_idx_i].head].next;
      end
    end

    if (reset_req || wr_rst_i) begin
      for (int i = 0; i < MaxRdTxns; i++) begin
        linked_data_d[i]          = '0;
        linked_data_d[i].free     = 1'b1;
      end
      for (int i = 0; i < HtCapacity; i++) begin
        head_tail_d[i]           = '0;
        head_tail_d[i].free      = 1'b1;
      end
    end
  end

endmodule