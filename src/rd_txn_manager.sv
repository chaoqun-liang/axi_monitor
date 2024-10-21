// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

// Authors:
// - Chaoqun Liang <chaoqun.liang@unibo.it>

module rd_txn_manager
  import slv_pkg::*;
#(
  parameter int unsigned MaxRdTxns  = 1,
  parameter int unsigned HtCapacity = 1,
  parameter int unsigned PtrWidth   = 1,
  parameter int unsigned LdIdxWidth = 1,
  parameter int unsigned PrescalerDiv = 1,
  parameter type linked_data_t  = logic,
  parameter type head_tail_t    = logic,
  parameter type ht_idx_t       = logic,
  parameter type ld_idx_t       = logic,
  parameter type req_t          = logic,
  parameter type rsp_t          = logic,
  parameter type id_t           = logic,
  parameter type accu_cnt_t     = logic,
  parameter type hs_cnt_t       = logic,
  parameter type cnt_t          = logic,
  parameter type hw2reg_t       = logic,
  parameter type reg2hw_t       = logic
)(
  input  logic                          rd_en_i,
  input  logic                          wr_rst_i,
  input  logic                          full_i,
  input  logic [1:0]                    budget_read,
  input  accu_cnt_t                     accum_burst_length,
  input  hs_cnt_t                       budget_rvld_rrdy_i,
  input  hs_cnt_t                       budget_arvld_arrdy_i,
  input  logic                          id_exists_i,
  output logic [LdIdxWidth-1:0] [MaxRdTxns-1:0] r_fifo_o,
  input  ld_idx_t                       active_idx_i,
  input  ht_idx_t                       rsp_idx_i,
  input  req_t                          mst_req_i,
  input  rsp_t                          slv_rsp_i,
  input  logic                          no_in_id_match_i,
  input  ht_idx_t                       head_tail_free_idx_i,
  input  ht_idx_t                       match_in_idx_i,
  input  ld_idx_t                       linked_data_free_idx_i,
  input  logic                          timeout_q_i,
  input  logic [PtrWidth-1:0]           wr_ptr_q_i,
  input  logic [PtrWidth-1:0]           rd_ptr_q_i,
  input  logic                          fifo_full_q_i,
  input  logic                          fifo_empty_q_i,
  output logic [PtrWidth-1:0]           wr_ptr_d_o,
  output logic [PtrWidth-1:0]           rd_ptr_d_o,
  output logic                          fifo_full_d_o,
  output logic                          fifo_empty_d_o,
  output logic                          timeout_o,
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

  accu_cnt_t arvld_rfirst_budget;
  cnt_t      rfirst_rlast_budget;

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
    timeout_o           = 1'b0;
    reset_req           = 1'b0;
    wr_ptr_d_o          = wr_ptr_q_i;
    rd_ptr_d_o          = rd_ptr_q_i;
    fifo_full_d_o       = fifo_full_q_i;
    fifo_empty_d_o      = fifo_empty_q_i;
    hw2reg_o.irq.r0.de = 1'b1;
    hw2reg_o.irq.r1.de = 1'b1;
    hw2reg_o.irq.r2.de = 1'b1;
    hw2reg_o.irq.r3.de = 1'b1;
    hw2reg_o.irq_addr.de = 1'b1;
    hw2reg_o.irq.txn_id.de = 1'b1;
    hw2reg_o.reset.de = 1'b1; 
    hw2reg_o.irq.irq.de = 1'b1;
    hw2reg_o.irq.unwanted_rd_resp.de = 1'b1;
    hw2reg_o.latency_arvld_arrdy.de = 1'b1;
    hw2reg_o.latency_arvld_rvld.de = 1'b1;
    hw2reg_o.latency_rvld_rrdy.de = 1'b1; 
    hw2reg_o.latency_rvld_rlast.de = 1'b1;
    
    hw2reg_o.latency_arvld_arrdy.d = reg2hw_i.latency_arvld_arrdy.q;
    hw2reg_o.latency_arvld_rvld.d  = reg2hw_i.latency_arvld_rvld.q;
    hw2reg_o.latency_rvld_rrdy.d   = reg2hw_i.latency_rvld_rrdy.q;
    hw2reg_o.latency_rvld_rlast.d  = reg2hw_i.latency_rvld_rlast.q;
    hw2reg_o.irq.unwanted_rd_resp.d    = reg2hw_i.irq.unwanted_rd_resp.q;
    hw2reg_o.irq.irq.d                  = reg2hw_i.irq.irq.q;
    hw2reg_o.irq.txn_id.d          = reg2hw_i.irq.txn_id.q;
    hw2reg_o.irq.r0.d              = reg2hw_i.irq.r0.q;
    hw2reg_o.irq.r1.d              = reg2hw_i.irq.r1.q;
    hw2reg_o.irq.r2.d              = reg2hw_i.irq.r2.q;
    hw2reg_o.irq.r3.d              = reg2hw_i.irq.r3.q;
    hw2reg_o.irq_addr.d            = reg2hw_i.irq_addr.q;
    hw2reg_o.reset.d               = reg2hw_i.reset.q; 
    
    // Enqueue
    if (rd_en_i && !full_i && !timeout_q_i) begin : proc_txn_enqueue
      match_in_id = mst_req_i.ar.id;
      match_in_id_valid = 1'b1;  
      arvld_rfirst_budget = accum_burst_length + 2;
      rfirst_rlast_budget = ( mst_req_i.ar.len + 1 ) << $clog2(PrescalerDiv) + 2;
      if ( mst_req_i.ar_valid && !fifo_full_q_i) begin: proc_r_fifo
        r_fifo_o[wr_ptr_q_i] = linked_data_free_idx_i;
        wr_ptr_d_o = (wr_ptr_q_i + 1) % MaxRdTxns;//circular buffer
        fifo_empty_d_o = 0;
        fifo_full_d_o = (rd_ptr_q_i == (wr_ptr_q_i + 1) % MaxRdTxns);
      end
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
        read_state: READ_ADDRESS,
        counters: 0,
        r1_budget: arvld_rfirst_budget,
        r3_budget: rfirst_rlast_budget,
        next: '0,
        free: 1'b0
      };
    end

    // Transaction states handling
    for ( int i = 0; i < MaxRdTxns; i++ ) begin : proc_rd_txn_states
      if (!linked_data_q[i].free) begin 
        case ( linked_data_q[i].read_state )
          READ_ADDRESS: begin
            if (linked_data_q[i].counters.cnt_arvalid_arready > budget_arvld_arrdy_i) begin
              timeout_o = 1'b1;
              reset_req = 1'b1;
              hw2reg_o.reset.d = 1'b1;
              hw2reg_o.irq.r0.d = 1'b1;
              hw2reg_o.irq.irq.d = 1'b1;
              hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id;
            end
            if (linked_data_q[i].counters.cnt_arvalid_rfirst  > linked_data_q[i].r1_budget) begin
              timeout_o = 1'b1;
              reset_req = 1'b1;
              hw2reg_o.reset.d = 1'b1;
              hw2reg_o.irq.r1.d = 1'b1; 
              hw2reg_o.irq.irq.d = 1'b1;
              hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id;
            end
            if ( slv_rsp_i.r_valid && mst_req_i.r_ready && (linked_data_q[i].metadata.id == slv_rsp_i.r.id) && !fifo_empty_q_i && (active_idx_i == i)) begin
              hw2reg_o.latency_arvld_arrdy.d = linked_data_q[i].counters.cnt_arvalid_arready;
              hw2reg_o.latency_arvld_rvld.d = linked_data_q[i].counters.cnt_arvalid_rfirst;
              linked_data_d[i].read_state = READ_DATA;
            end
            // for bursts of single transfer, r_valid and r_last asserted at the same cycle
            if ( slv_rsp_i.r_valid && slv_rsp_i.r.last && (linked_data_q[i].metadata.id == slv_rsp_i.r.id) && !fifo_empty_q_i && (active_idx_i == i)) begin
              hw2reg_o.latency_arvld_arrdy.d = linked_data_q[i].counters.cnt_arvalid_arready;
              hw2reg_o.latency_arvld_rvld.d = linked_data_q[i].counters.cnt_arvalid_rfirst;
              linked_data_d[i].read_state = READ_DATA;
            end
          end

          READ_DATA: begin
            if ( linked_data_q[i].counters.cnt_rvalid_rready_first > budget_rvld_rrdy_i ) begin
              timeout_o = 1'b1;
              hw2reg_o.irq.r2.d = 1'b1;
              hw2reg_o.irq.irq.d = 1'b1;
              hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id;
            end
            if ( linked_data_q[i].counters.cnt_rfirst_rlast > linked_data_q[i].r3_budget) begin
              timeout_o = 1'b1;
              hw2reg_o.irq.r3.d = 1'b1;
              reset_req = 1'b1;
              hw2reg_o.reset.d = 1'b1;
              hw2reg_o.irq.irq.d = 1'b1;
              hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id;
            end
          end
          default: begin
            linked_data_d[i].read_state = READ_IDLE;
          end
        endcase
      end 
    end

    // check transaction completion
    if ( slv_rsp_i.r.last && slv_rsp_i.r_valid && mst_req_i.r_ready ) begin
      if( id_exists_i ) begin
        oup_req = 1; 
        oup_id = slv_rsp_i.r.id;
        hw2reg_o.latency_rvld_rrdy.d = linked_data_q[head_tail_q[rsp_idx_i].head].counters.cnt_rvalid_rready_first;
        hw2reg_o.latency_rvld_rlast.d = linked_data_q[head_tail_q[rsp_idx_i].head].r3_budget - linked_data_q[head_tail_q[rsp_idx_i].head].counters.cnt_rfirst_rlast;
        rd_ptr_d_o = (rd_ptr_q_i + 1)% MaxRdTxns;  // Update read pointer after last W data
        fifo_empty_d_o = (rd_ptr_q_i == wr_ptr_q_i) && ( wr_ptr_q_i != 0);
      end else begin 
        hw2reg_o.irq.unwanted_rd_resp.d = 'b1;
        hw2reg_o.reset.d = 1'b1;
        reset_req = 1'b1;
        hw2reg_o.irq.irq.d = 1'b1;
      end
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

    if (reset_req || wr_rst_i || timeout_o ) begin
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