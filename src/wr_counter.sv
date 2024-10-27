// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

module wr_counter
  import slv_pkg::*;
#(
  parameter int unsigned CntWidth     = 2,
  parameter type linked_data_t        = logic,
  parameter type id_t                 = logic
) (
  input  logic         clk_i,           // Clock input
  input  logic         rst_ni,
  input  logic         prescaled_en_i,
  input  id_t          slv_b_id_i,
  input  logic         aw_ready_sticky_i,
  input  logic         b_valid_sticky_i,
  input  logic         b_ready_sticky_i,
  input  logic         w_valid_sticky_i,
  input  logic         w_ready_sticky_i,
  input  linked_data_t linked_data_d_i, // Input data for the linked_data_q
  output linked_data_t linked_data_q_o  // Output data after processing
);

  // Internal register to hold the linked data
  linked_data_t linked_data_q;

  assign linked_data_q_o = linked_data_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      linked_data_q <= '0;
      // mark all slots as free
      linked_data_q.free <= 1'b1;
    end else begin
      linked_data_q  <= linked_data_d_i;
      // only if this slot is in use, that is to say there is an outstanding transaction
      if (!linked_data_q.free) begin
        case (linked_data_q.write_state)
          WRITE_ADDRESS: begin
            // Counter 0: AW Phase - AW_VALID to AW_READY, handshake is checked meanwhile
            if (!aw_ready_sticky_i && prescaled_en_i) begin
              linked_data_q.counters.cnt_awvalid_awready <= linked_data_q.counters.cnt_awvalid_awready + 1 ; // note: cannot do self-increment
            end
            // Counter 1: AW Phase - AW_VALID to W_VALID (first data)
            if (prescaled_en_i)
              linked_data_q.counters.cnt_awvalid_wfirst <= linked_data_q.counters.cnt_awvalid_wfirst + 1;
          end
          WRITE_DATA: begin
            // Counter 2: W Phase - W_VALID to W_READY (first data), handshake of first data is checked
            if (!(w_valid_sticky_i && w_ready_sticky_i) && prescaled_en_i) begin
              linked_data_q.counters.cnt_wvalid_wready_first  <= linked_data_q.counters.cnt_wvalid_wready_first + 1;
            end
            // Counter 3: W Phase - W_VALID(W_FIRST) to W_LAST
            //if (!mst_req_i.w.last)
            if (prescaled_en_i)
              linked_data_q.counters.cnt_wfirst_wlast  <= linked_data_q.counters.cnt_wfirst_wlast + 1;
          end
          WRITE_RESPONSE: begin
            // B_valid comes the cycle after w_last.
            // Counter 4: B Phase - W_LAST to B_VALID
            if(!b_valid_sticky_i && prescaled_en_i)
              linked_data_q.counters.cnt_wlast_bvalid <= linked_data_q.counters.cnt_wlast_bvalid + 1;
            // Counter 5: B Phase - B_VALID to B_READY, handshake is checked, stop counting upon handshake
            if(!(b_valid_sticky_i && b_ready_sticky_i) && prescaled_en_i)
              linked_data_q.counters.cnt_bvalid_bready <= linked_data_q.counters.cnt_bvalid_bready +1;
          end
        endcase
      end
    end
  end
endmodule
