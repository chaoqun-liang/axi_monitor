// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
module txn_track #(
  parameter int unsigned  MaxWrTxns  = 1, 
  parameter int unsigned  HtCapacity = 1,
  parameter type linked_data_t      = logic,
  parameter type head_tail_t        = logic,
  parameter type ht_idx_t           = logic,
  parameter type id_t               = logic,
  parameter type ld_idx_t           = logic,
  parameter type hw2reg_t           = logic,
  parameter type reg2hw_t           = logic
) (
  input  linked_data_t [MaxWrTxns-1:0]   linked_data_q_i,
  input  logic                           slv_b_valid_i,
  input  logic                           mst_b_ready_i,
  input  logic                           id_exists,
  input  id_t                            slv_b_id_i,
  input  head_tail_t [HtCapacity-1:0]    head_tail_q_i,
  input  ht_idx_t                        rsp_idx_i,
  input  logic                           reset_req_q_i,
  input  logic                           prescaled_en,
  input  logic                           b_valid_sticky,
  input  logic                           b_ready_sticky,
  output linked_data_t [MaxWrTxns-1:0]   linked_data_d_o,
  output logic                           timeout_o,
  output logic                           reset_req_o,
  output hw2reg_t                        hw2reg_o,
  input  reg2hw_t                        reg2hw_i,
  output logic                           oup_req_o,
  output id_t                            oup_id_o
);

  // Internal signals
  linked_data_t [MaxWrTxns-1:0] linked_data_d;
  logic         timeout;
  logic         reset_req;
  // Initialize outputs
  assign linked_data_d_o = linked_data_d;
  assign timeout_o       = timeout;
  assign reset_req_o     = reset_req;

  assign hw2reg_o.irq.unwanted_wr_resp.de = 1'b1;
  assign hw2reg_o.irq.irq.de              = 1'b1;
  assign hw2reg_o.irq.wr_timeout.de       = 1'b1;
  assign hw2reg_o.irq.txn_id.de       = 1'b1;
  assign hw2reg_o.irq_addr.de         = 1'b1;
  assign hw2reg_o.reset.de            = 1'b1; 
  assign hw2reg_o.latency_write.de    = 1'b1;

  always_comb begin: proc_wr_states
    // Initialize outputs
    linked_data_d = linked_data_q_i;
    reset_req     = reset_req_q_i;
    oup_req_o     = 1'b0;
    oup_id_o      = '0;
    hw2reg_o.irq.unwanted_wr_resp.d = reg2hw_i.irq.unwanted_wr_resp.q;
    hw2reg_o.irq.txn_id.d       = reg2hw_i.irq.txn_id.q;
    hw2reg_o.irq.wr_timeout.d   = reg2hw_i.irq.wr_timeout.q;
   // hw2reg_o.irq.irq.d          = reg2hw_i.irq.irq.q;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 .irq_addr.q;
    hw2reg_o.reset.d            = reg2hw_i.reset.q;
    hw2reg_o.latency_write.d    = reg2hw_i.latency_write.q;
    
    for ( int i = 0; i < MaxWrTxns; i++) begin
      if (!linked_data_q_i[i].free) begin
        // Check for timeout
        if (linked_data_q_i[i].counter == 0) begin
          timeout           = 1'b1;
          hw2reg_o.irq.wr_timeout.d = 1'b1;
          reset_req           = 1'b1;
          hw2reg_o.reset.d    = 1'b1;
          hw2reg_o.irq.txn_id.d = linked_data_q_i[i].metadata.id;
          hw2reg_o.irq.irq.d  = 1'b1;
        end

        // Handle slave response
        if (slv_b_valid_i && mst_b_ready_i ) begin
          if (id_exists) begin
            linked_data_d[i].found_match = ((linked_data_q_i[i].metadata.id == slv_b_id_i) &&
                                                 (head_tail_q_i[rsp_idx_i].head == i)) ? 1'b1 : 1'b0;
          end else begin
            hw2reg_o.irq.unwanted_wr_resp.d = 1'b1;
            hw2reg_o.reset.d                = 1'b1;
            reset_req                       = 1'b1;
            hw2reg_o.irq.irq.d              = 1'b1;
          end
        end

        // If found match, prepare to dequeue
        if (linked_data_q_i[i].found_match) begin
          oup_req_o             = 1'b1;
          oup_id_o              = linked_data_q_i[i].metadata.id;
          hw2reg_o.latency_write.d = linked_data_q_i[i].counter;
          linked_data_d[i]         = '0;
          linked_data_d[i].counter = '0;
          linked_data_d[i].free    = 1'b1;
        end
      end
    end

    if (reset_req) begin
      // Clear all linked data slots
      for (int i = 0; i < MaxWrTxns; i++) begin
        if (!linked_data_q_i[i].free) begin
          oup_req_o                         = 1'b1;
          oup_id_o                          = linked_data_q_i[i].metadata.id;
          // Clear the linked data entry
          linked_data_d[i]                = '{default:'0};
          linked_data_d[i].counter        = '0;
          linked_data_d[i].free           = 1'b1;
        end
      end
    end
  end
endmodule

