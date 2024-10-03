// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

module txn_enqueue #(
  parameter int  unsigned PrescalerDiv   = 1, // Prescaler divisor
  parameter int  unsigned MaxWrTxns       = 1,
  parameter int  unsigned HtCapacity      = 1,
  parameter type ht_idx_t                = logic, // Metadata type
  parameter type linked_data_t           = logic, // Linked data type
  parameter type accu_cnt_t              = logic,
  parameter type int_id_t                = logic, 
  parameter type head_tail_t             = logic,
  parameter type ld_idx_t                = logic,
  parameter type req_t                   = logic
)(
  input  logic                 wr_en_i,        // Write enable input
  input  logic                 inp_gnt_i,        // Input grant signal
  input  ht_idx_t              match_in_idx_i,  // Index of matching ID
  input  ht_idx_t              match_out_idx_i,
  input  ld_idx_t              oup_data_free_idx_i,
  input  ld_idx_t              linked_data_free_idx_i,
  input  ht_idx_t              head_tail_free_idx_i,
  input  int_id_t              oup_id_i,
  input  req_t                 mst_req_i,
  input  logic                 oup_ht_popped_i,  // Flag indicating if head tail popped
  input  logic                 no_in_id_match_i, // No matching ID in head tail
  input  logic                 oup_data_popped_i,// Flag indicating if output data popped
  input  logic [2:0]           budget_write_i,   // Unit budget write value
  input  accu_cnt_t            accum_burst_length_i, // Accumulated burst length
  input  int_id_t              mst_aw_id_i, // Request ID for AW channel
  input  axi_pkg::len_t        mst_aw_len_i, // Request length for AW channel
  input  head_tail_t [HtCapacity-1:0]   head_tail_q_i,
  output head_tail_t [HtCapacity-1:0]   head_tail_d_o,    // Head-tail data
  output linked_data_t [MaxWrTxns-1:0]  linked_data_d_o   // Linked data
);
  
  accu_cnt_t     txn_budget;     // Calculated transaction budget
  
  always_comb begin
    if (wr_en_i && inp_gnt_i) begin : proc_txn_enqueue
      // Calculate transaction budget
      txn_budget = (budget_write_i * accum_burst_length_i) +
                   (budget_write_i * (mst_aw_len_i + 1) / PrescalerDiv) + 1; // Count itself

      // Head-tail repopulation logic
      if (oup_ht_popped_i && (oup_id_i == mst_aw_id_i)) begin
        head_tail_d_o[match_out_idx_i] = '{
          id: mst_aw_id_i,
          head: oup_data_free_idx_i,
          tail: oup_data_free_idx_i,
          free: 1'b0
        }; 
        linked_data_d_o[oup_data_free_idx_i] = '{
          //metadata: '{id: mst_aw_id_i, len: mst_aw_len_i},
          metadata: mst_req_i.aw,
          counter: txn_budget,
          found_match: 0,
          next: '0,
          free: 1'b0
        };
      end else if (no_in_id_match_i) begin
        // If no matching ID exists
        if (oup_ht_popped_i) begin
          head_tail_d_o[match_out_idx_i] = '{
            id: mst_aw_id_i,
            head: oup_data_free_idx_i,
            tail: oup_data_free_idx_i,
            free: 1'b0
          };
          linked_data_d_o[oup_data_free_idx_i] = '{
            //metadata: '{id: mst_aw_id_i, len: mst_aw_len_i},
            metadata: mst_req_i.aw,
            counter: txn_budget,
            found_match: 0,
            next: '0,
            free: 1'b0
          };
        end else if (oup_data_popped_i) begin
          head_tail_d_o[head_tail_free_idx_i] = '{
            id: mst_aw_id_i,
            head: oup_data_free_idx_i,
            tail: oup_data_free_idx_i,
            free: 1'b0
          };
          linked_data_d_o[oup_data_free_idx_i] = '{
            //metadata: '{id: mst_aw_id_i, len: mst_aw_len_i},
            metadata: mst_req_i.aw,
            counter: txn_budget,
            found_match: 0,
            next: '0,
            free: 1'b0
          };
        end else begin
          head_tail_d_o[head_tail_free_idx_i] = '{
            id: mst_aw_id_i,
            head: linked_data_free_idx_i,
            tail: linked_data_free_idx_i,
            free: 1'b0
          };
          linked_data_d_o[linked_data_free_idx_i] = '{
            //metadata: '{id: mst_aw_id_i, len: mst_aw_len_i},
            metadata: mst_req_i.aw,
            counter: txn_budget,
            found_match: 0,
            next: '0,
            free: 1'b0
          };
        end
      end else begin
        // Append to existing ID subqueue
        if (oup_data_popped_i) begin
          linked_data_d_o[head_tail_q_i[match_in_idx_i].tail].next = oup_data_free_idx_i;
          head_tail_d_o[match_in_idx_i].tail = oup_data_free_idx_i;
          linked_data_d_o[oup_data_free_idx_i] = '{
            //metadata: '{id: mst_aw_id_i, len: mst_aw_len_i},
            metadata: mst_req_i.aw,
            counter: txn_budget,
            found_match: 0,
            next: '0,
            free: 1'b0
          };
        end else begin
          linked_data_d_o[head_tail_q_i[match_in_idx_i].tail].next = linked_data_free_idx_i;
          head_tail_d_o[match_in_idx_i].tail = linked_data_free_idx_i;
          linked_data_d_o[linked_data_free_idx_i] = '{
            //metadata: '{id: mst_aw_id_i, len: mst_aw_len_i},
            metadata: mst_req_i.aw,
            counter: txn_budget,
            found_match: 0,
            next: '0,
            free: 1'b0
          };
        end
      end
    end
  end
endmodule
