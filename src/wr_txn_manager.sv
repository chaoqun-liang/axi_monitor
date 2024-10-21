// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

// Authors:
// - Chaoqun Liang <chaoqun.liang@unibo.it>

module wr_txn_manager 
  import slv_pkg::*;
#(
  parameter int unsigned MaxWrTxns  = 1,
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
  input  logic                          wr_en_i,
  input  logic                          rd_rst_i,
  input  logic                          full_i,
  input  hs_cnt_t                       budget_awvld_awrdy_i,
  input  hs_cnt_t                       budget_wvld_wrdy_i,
  input  hs_cnt_t                       budget_wlast_bvld_i,
  input  hs_cnt_t                       budget_bvld_brdy_i,
  input  accu_cnt_t                     accum_burst_length,
  input  logic                          id_exists_i,
  output logic [LdIdxWidth-1:0] [MaxWrTxns-1:0] w_fifo_o,
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
  input  ld_idx_t                       active_idx_i,
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
  input  linked_data_t [MaxWrTxns-1:0]  linked_data_q,
  output linked_data_t [MaxWrTxns-1:0]  linked_data_d,
  output hw2reg_t                       hw2reg_o,
  input  reg2hw_t                       reg2hw_i
);
  
  accu_cnt_t awvld_wfirst_budget;
  cnt_t      wfirst_wlast_budget;
  // Transaction states handling
  always_comb begin : proc_wr_queue
    match_in_id         = '0;
    match_in_id_valid   = 1'b0;
    head_tail_d         = head_tail_q;
    linked_data_d       = linked_data_q;
    oup_data_valid      = 1'b0;
    oup_data_popped     = 1'b0;
    oup_ht_popped       = 1'b0;
    oup_id              = '0;
    oup_req             = 1'b0;
    timeout_o           = 1'b0;
    reset_req           = 1'b0;
    wr_ptr_d_o            = wr_ptr_q_i;
    rd_ptr_d_o            = rd_ptr_q_i;
    fifo_full_d_o         = fifo_full_q_i;
    fifo_empty_d_o        = fifo_empty_q_i;
    hw2reg_o.irq.w0.de = 1'b1;
    hw2reg_o.irq.w1.de = 1'b1;
    hw2reg_o.irq.w2.de = 1'b1;
    hw2reg_o.irq.w3.de = 1'b1;
    hw2reg_o.irq.w4.de = 1'b1;
    hw2reg_o.irq.w5.de = 1'b1;
    hw2reg_o.irq_addr.de = 1'b1;
    hw2reg_o.irq.txn_id.de = 1'b1;
    hw2reg_o.reset.de = 1'b1; 
    hw2reg_o.irq.irq.de = 1'b1;
    hw2reg_o.irq.unwanted_wr_resp.de = 1'b1;
    hw2reg_o.latency_awvld_awrdy.de = 1'b1;
    hw2reg_o.latency_awvld_wfirst.de = 1'b1;
    hw2reg_o.latency_wvld_wrdy.de = 1'b1; 
    hw2reg_o.latency_wvld_wlast.de = 1'b1;
    hw2reg_o.latency_wlast_bvld.de = 1'b1;
    hw2reg_o.latency_bvld_brdy.de = 1'b1;

    hw2reg_o.latency_awvld_awrdy.d  = reg2hw_i.latency_awvld_awrdy.q;
    hw2reg_o.latency_awvld_wfirst.d = reg2hw_i.latency_awvld_wfirst.q;
    hw2reg_o.latency_wlast_bvld.d   = reg2hw_i.latency_wlast_bvld.q;
    hw2reg_o.latency_bvld_brdy.d    = reg2hw_i.latency_bvld_brdy.q;
    hw2reg_o.latency_awvld_awrdy.d  = reg2hw_i.latency_awvld_awrdy.q;
    hw2reg_o.latency_awvld_wfirst.d = reg2hw_i.latency_awvld_wfirst.q;
    hw2reg_o.irq.w0.d               = reg2hw_i.irq.w0.q;
    hw2reg_o.irq.w1.d               = reg2hw_i.irq.w1.q;
    hw2reg_o.irq.w2.d               = reg2hw_i.irq.w2.q;
    hw2reg_o.irq.w3.d               = reg2hw_i.irq.w3.q;
    hw2reg_o.irq.w4.d               = reg2hw_i.irq.w4.q;
    hw2reg_o.irq.w5.d               = reg2hw_i.irq.w5.q;
    hw2reg_o.irq.txn_id.d           = reg2hw_i.irq.txn_id.q;
    hw2reg_o.irq_addr.d             = reg2hw_i.irq_addr.q;
    hw2reg_o.irq.irq.d              = reg2hw_i.irq.irq.q;
    hw2reg_o.reset.d                = reg2hw_i.reset.q; 
    hw2reg_o.irq.unwanted_wr_resp.d = reg2hw_i.irq.unwanted_wr_resp.q;
    
    // Enqueue
    if (wr_en_i && !full_i && !timeout_q_i)begin : proc_txn_enqueue
      match_in_id = mst_req_i.aw.id;
      match_in_id_valid = 1'b1;  
      awvld_wfirst_budget = accum_burst_length + 2; // to-do: if not the first txn in ld, use w_fifo
      wfirst_wlast_budget = (mst_req_i.aw.len + 1) >> $clog2(PrescalerDiv) + 2;
      if (mst_req_i.aw_valid && !fifo_full_q_i) begin: proc_w_fifo
        w_fifo_o[wr_ptr_d_o] = linked_data_free_idx_i;
        wr_ptr_d_o = (wr_ptr_q_i + 1)  % MaxWrTxns;//circular buffer
        fifo_empty_d_o = 0;
        fifo_full_d_o = (rd_ptr_q_i == (wr_ptr_q_i + 1) % MaxWrTxns);
      end
      if (no_in_id_match_i) begin
        head_tail_d[head_tail_free_idx_i] = '{
          id: mst_req_i.aw.id,
          head: linked_data_free_idx_i,
          tail: linked_data_free_idx_i,
          free: 1'b0
        };
      end else begin 
        linked_data_d[head_tail_q[match_in_idx_i].tail].next = linked_data_free_idx_i;
        head_tail_d[match_in_idx_i].tail = linked_data_free_idx_i;
      end
      linked_data_d[linked_data_free_idx_i] = '{
        metadata: '{id: mst_req_i.aw.id, len: mst_req_i.aw.len},
        write_state: WRITE_ADDRESS,
        counters: 0,
        w1_budget: awvld_wfirst_budget,
        w3_budget: wfirst_wlast_budget,
        next: '0,
        free: 1'b0
      };
    end

    // Transaction states handling
    for ( int i = 0; i < MaxWrTxns; i++ ) begin : proc_wr_txn_states
      if (!linked_data_q[i].free) begin 
        case ( linked_data_q[i].write_state ) 
          WRITE_ADDRESS: begin
            if (linked_data_q[i].counters.cnt_awvalid_awready > budget_awvld_awrdy_i) begin
              timeout_o = 1'b1;
              reset_req = 1'b1;
              hw2reg_o.reset.d = 1'b1;
              hw2reg_o.irq.w0.d = 1'b1;
              hw2reg_o.irq.irq.d = 1'b1;
              hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id;
            end 
            if( linked_data_q[i].counters.cnt_awvalid_wfirst >  linked_data_q[i].w1_budget) begin
              timeout_o = 1'b1;
              hw2reg_o.irq.w1.d = 1'b1;
              hw2reg_o.irq.irq.d = 1'b1; 
              hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id; 
            end
            // to enter write_data state, last txn has done one w channel
            // w_valid comes and next active transaction on w channel points to current one
            if ( mst_req_i.w_valid && !fifo_empty_q_i && (active_idx_i == i)) begin
              hw2reg_o.latency_awvld_awrdy.d = linked_data_q[i].counters.cnt_awvalid_awready;
              hw2reg_o.latency_awvld_wfirst.d = linked_data_q[i].w1_budget - linked_data_q[i].counters.cnt_awvalid_wfirst;
              linked_data_d[i].write_state = WRITE_DATA;
            end 
            // single transfer transaction where w_valid and w_last are shown at the same cycle
            if ( ( mst_req_i.w_valid && mst_req_i.w.last ) && !fifo_empty_q_i && (active_idx_i == i)) begin
              hw2reg_o.latency_awvld_awrdy.d = linked_data_q[i].counters.cnt_awvalid_awready;
              hw2reg_o.latency_awvld_wfirst.d = linked_data_q[i].w1_budget - linked_data_q[i].counters.cnt_awvalid_wfirst;
              linked_data_d[i].write_state = WRITE_DATA;
            end 
          end

          WRITE_DATA: begin
            if (linked_data_q[i].counters.cnt_wvalid_wready_first > budget_wvld_wrdy_i) begin
              timeout_o = 1'b1;
              reset_req = 1'b1;
              hw2reg_o.reset.d = 1'b1;
              hw2reg_o.irq.w2.d = 1'b1;
              hw2reg_o.irq.irq.d = 1'b1;
              hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id;
            end 
            if (linked_data_q[i].counters.cnt_wfirst_wlast > linked_data_q[i].w3_budget) begin
              timeout_o = 1'b1;
              hw2reg_o.irq.w3.d = 1'b1;
              hw2reg_o.irq.irq.d = 1'b1;
              hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id;
            end                                                                                                                        
            if ( mst_req_i.w.last ) begin
              hw2reg_o.latency_wvld_wrdy.d = linked_data_q[i].counters.cnt_wvalid_wready_first;
              hw2reg_o.latency_wvld_wlast.d = linked_data_q[i].w3_budget - linked_data_q[i].counters.cnt_wfirst_wlast;
              linked_data_d[i].write_state = WRITE_RESPONSE;
              rd_ptr_d_o = (rd_ptr_q_i + 1)% MaxWrTxns;  //  some synthesis tool can optimize the % operation
              fifo_empty_d_o = (rd_ptr_q_i == wr_ptr_q_i) && ( wr_ptr_q_i != 0); 
            end
          end

          WRITE_RESPONSE: begin
            if ( linked_data_q[i].counters.cnt_wlast_bvalid > budget_wlast_bvld_i ) begin
              timeout_o = 1'b1;
              reset_req = 1'b1;
              hw2reg_o.reset.d = 1'b1;
              hw2reg_o.irq.w4.d = 1'b1;
              hw2reg_o.irq.irq.d = 1'b1;
              hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id;
            end
            if ( linked_data_q[i].counters.cnt_bvalid_bready > budget_bvld_brdy_i) begin
              timeout_o = 1'b1;
              hw2reg_o.irq.w5.d = 1'b1;
              hw2reg_o.irq.irq.d = 1'b1;
              hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id;
            end
          end
          default:
            linked_data_d[i].write_state = WRITE_IDLE;
        endcase
      end
    end

    if ( mst_req_i.b_ready && slv_rsp_i.b_valid ) begin 
      if ( id_exists_i ) begin 
        oup_req = 1; 
        oup_id = slv_rsp_i.b.id;
        //$display("found match! oup_req = %0d, oup_id = %0d", oup_req, oup_id);
        hw2reg_o.latency_wlast_bvld.d = linked_data_q[head_tail_q[rsp_idx_i].head].counters.cnt_wlast_bvalid;
        hw2reg_o.latency_bvld_brdy.d = linked_data_q[head_tail_q[rsp_idx_i].head].counters.cnt_bvalid_bready;
      end else begin
        reset_req = 1'b1;
        hw2reg_o.reset.d = 1'b1;
        hw2reg_o.irq.unwanted_wr_resp.d = 'b1;
        hw2reg_o.irq.irq.d = 1'b1;
      end 
    end

    if (reset_req || rd_rst_i || timeout_o) begin
      for (int i = 0; i < MaxWrTxns; i++) begin
        linked_data_d[i]          = '0;
        linked_data_d[i].free     = 1'b1;
      end
      for (int i = 0; i < HtCapacity; i++) begin
        head_tail_d[i]           = '0;
        head_tail_d[i].free      = 1'b1;
      end
    end

    // Dequeue 
    if (oup_req) begin : proc_txn_dequeue // Same as id_exists_i
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
  end

endmodule