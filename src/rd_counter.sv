// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

module rd_counter 
  import slv_pkg::*;
#(
  parameter int unsigned CntWidth = 2,
  parameter type linked_data_t    = logic,
  parameter type id_t             = logic
) (
  input  logic         clk_i,           // Clock input
  input  logic         rst_ni,          // Asynchronous reset (active low)
  input  id_t          slv_b_id_i,
  input  logic         ar_ready_i,
  input  logic         r_valid_i,
  input  logic         r_ready_i, 
  input  logic         r_last_i,
  input  linked_data_t linked_data_d_i, // Input data for the linked_data_q
  output linked_data_t linked_data_q_o  // Output data after processing
);

  // Internal register to hold the linked data
  linked_data_t linked_data_q;   // Register for linked data
  // Assign output
  assign linked_data_q_o = linked_data_q;

  // Always block for clocked process
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      linked_data_q <= '0;
      linked_data_q.free   <= 1'b1;
    end else begin
      // Normal operation, update linked_data_q and counter
      linked_data_q <= linked_data_d_i;
      // Only if this slot is in use (i.e., there is an outstanding transaction)
      if (!linked_data_q.free) begin
        case (linked_data_q.read_state) 
          1: begin
            // Counter 0: AR Phase - AR_VALID to AR_READY, handshake is checked meanwhile
            if (!ar_ready_i) begin
              linked_data_q.counters.cnt_arvalid_arready <= linked_data_q.counters.cnt_arvalid_arready + 1 ; // note: cannot do auto-increment
            end
            // Counter 1: AR Phase - AR_VALID to R_VALID (first data)
            linked_data_q.counters.cnt_arvalid_rfirst <= linked_data_q.counters.cnt_arvalid_rfirst + 1;
          end
          2: begin
            if( r_valid_i && !r_ready_i )
            // Counter 2: R Phase - R_VALID to R_READY (first data), handshake of first data is checked
              linked_data_q.counters.cnt_rvalid_rready_first  <= linked_data_q.counters.cnt_rvalid_rready_first + 1;
            // Counter 3: R Phase - R_VALID to R_LAST
            linked_data_q.counters.cnt_rfirst_rlast  <= linked_data_q.counters.cnt_rfirst_rlast + 1;
          end
        endcase
      end
    end
  end
endmodule