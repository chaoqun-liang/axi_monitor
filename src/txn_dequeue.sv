// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

module txn_dequeue #(
    parameter int unsigned MaxWrTxns  = 1,
    parameter int unsigned HtCapacity = 1,
    parameter type linked_data_t = logic,   // Define the type for linked_data
    parameter type head_tail_t   = logic,     // Define the type for head_tail data
    parameter type id_t          = logic,
    parameter type ht_idx_t      = logic
) (
    input  logic                         oup_req_i,          // Request signal to dequeue
    input  logic                         no_out_id_match_i,  // Signal to check if ID exists
    input  head_tail_t [HtCapacity-1:0]  head_tail_q_i,    // Head-tail queue input
    input  linked_data_t [MaxWrTxns-1:0] linked_data_q_i, // Linked data queue input
    input  ht_idx_t                      match_out_idx_i,    // Output match index
    input  id_t                          oup_id_i,           // Output ID
    output logic                         oup_data_valid_o,   // Output data valid signal
    output logic                         oup_data_popped_o,  // Output data popped signal
    output logic                         oup_ht_popped_o,    // Output HT popped signal
    output head_tail_t [HtCapacity-1:0]  head_tail_d_o,   // Head-tail data
    output linked_data_t [MaxWrTxns-1:0] linked_data_d_o // Linked data output
);

    always_comb begin
        // Default assignments
        oup_data_valid_o  = 1'b0;
        oup_data_popped_o = 1'b0;
        oup_ht_popped_o   = 1'b0;
        head_tail_d_o     = head_tail_q_i;
        linked_data_d_o   = linked_data_q_i;

        // If output request is valid, proceed with dequeue
        if (oup_req_i) begin
            // Set the match output ID as valid
            if (!no_out_id_match_i) begin
                oup_data_valid_o  = 1'b1;
                oup_data_popped_o = 1'b1;
                
                // Free the linked data entry
                linked_data_d_o[head_tail_q_i[match_out_idx_i].head] = '0;
                linked_data_d_o[head_tail_q_i[match_out_idx_i].head].free = 1'b1;

                // If it's the last entry for this ID, free the head-tail entry
                if (head_tail_q_i[match_out_idx_i].head == head_tail_q_i[match_out_idx_i].tail) begin
                    oup_ht_popped_o = 1'b1;
                    head_tail_d_o[match_out_idx_i] = '{free: 1'b1, default: '0};
                end else begin
                    // Move the head pointer forward in the linked list
                    head_tail_d_o[match_out_idx_i].head = linked_data_q_i[head_tail_q_i[match_out_idx_i].head].next;
                end
            end
        end
    end

endmodule
