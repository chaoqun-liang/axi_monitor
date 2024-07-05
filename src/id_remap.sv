// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

module id_remap #(
  /// ID width of the AXI4+ATOP slave port.
  parameter int unsigned AxiSlvPortIdWidth = 32'd0,
  /// Maximum number of different IDs that can be in flight at the slave port.  Reads and writes are
  parameter int unsigned AxiSlvPortMaxUniqIds = 32'd0,
  /// Maximum number of in-flight transactions with the same ID.
  parameter int unsigned AxiMaxTxnsPerId = 32'd0,
  parameter int unsigned AxiMstPortIdWidth = 32'd0,
  /// Request struct type of the AXI4+ATOP slave port.
  parameter type slv_req_t  = logic,
  /// Response struct type of the AXI4+ATOP slave port.
  parameter type slv_resp_t = logic,
  /// Request struct type of the AXI4+ATOP master port
  parameter type mst_req_t  = logic,
  /// Response struct type of the AXI4+ATOP master port
  parameter type mst_resp_t = logic
) (
  input  logic      clk_i,
  input  logic      rst_ni,
  input  slv_req_t  slv_req_i,
  output slv_resp_t slv_resp_o,
  output mst_req_t  mst_req_o,
  input  mst_resp_t mst_resp_i
);
 
// To retain ID independency, we have param assertions AxiMstPortIdWidth <= AxiSlvPortIdWidth
if (AxiMstPortIdWidth < AxiSlvPortIdWidth) begin : gen_remap
  axi_id_remap #(
    .AxiSlvPortIdWidth    ( AxiSlvPortIdWidth       ),
    .AxiMstPortIdWidth    ( AxiMstPortIdWidth       ),
    .AxiSlvPortMaxUniqIds ( AxiSlvPortMaxUniqIds    ),
    .AxiMaxTxnsPerId      ( AxiMaxTxnsPerId         ),
    .slv_req_t            ( slv_req_t               ),
    .slv_resp_t           ( slv_resp_t              ),
    .mst_req_t            ( mst_req_t               ),
    .mst_resp_t           ( mst_resp_t              )
  ) i_axi_id_remap (
    .clk_i,
    .rst_ni,
    .slv_req_i  ( slv_req_i  ),
    .slv_resp_o ( slv_resp_o ),
    .mst_req_o  ( mst_req_o  ),
    .mst_resp_i ( mst_resp_i )
  );
end else begin : gen_passthru
    assign mst_req_o  = slv_req_i;
    assign slv_resp_o = mst_resp_i;
  end

  // Validate parameters.
`ifndef SYNTHESIS
`ifndef COMMON_CELLS_ASSERTS_OFF
  initial begin: validate_params
    assert(AxiSlvPortIdWidth > 32'd0)
      else $fatal(1, "Parameter AxiSlvPortIdWidth has to be larger than 0!");
    assert (AxiSlvPortMaxUniqIds > 0)
      else $fatal(1, "Parameter AxiSlvPortMaxUniqIds has to be larger than 0!");
    assert (AxiMstPortIdWidth <= AxiSlvPortIdWidth)
      else $fatal(1, "Parameter AxiSlvPortMaxIdWidth has to be at least AxiMstPortIdWidth ");   
    assert (AxiSlvPortMaxUniqIds <= 2**AxiMstPortIdWidth)
      else $fatal(1, "Parameter AxiSlvPortMaxUniqIds may be at most 2**AxiMstPortIdWidth!"); 
    assert (AxiMaxTxnsPerId > 0)
      else $fatal(1, "Parameter AxiMaxTxnsPerId has to be larger than 0!");
    assert($bits(slv_req_i.aw.addr) == $bits(mst_req_o.aw.addr))
      else $fatal(1, "AXI AW address widths are not equal!");
    assert($bits(slv_req_i.w.data) == $bits(mst_req_o.w.data))
      else $fatal(1, "AXI W data widths are not equal!");
    assert($bits(slv_req_i.w.user) == $bits(mst_req_o.w.user))
      else $fatal(1, "AXI W user widths are not equal!");
    assert($bits(slv_req_i.ar.addr) == $bits(mst_req_o.ar.addr))
      else $fatal(1, "AXI AR address widths are not equal!");
    assert($bits(slv_resp_o.r.data) == $bits(mst_resp_i.r.data))
      else $fatal(1, "AXI R data widths are not equal!");
    assert ($bits(slv_req_i.aw.id) == AxiSlvPortIdWidth);
    assert ($bits(slv_resp_o.b.id) == AxiSlvPortIdWidth);
    assert ($bits(slv_req_i.ar.id) == AxiSlvPortIdWidth);
    assert ($bits(slv_resp_o.r.id) == AxiSlvPortIdWidth);
    assert ($bits(mst_req_o.aw.id) == AxiMstPortIdWidth);
    assert ($bits(mst_resp_i.b.id) == AxiMstPortIdWidth);
    assert ($bits(mst_req_o.ar.id) == AxiMstPortIdWidth);
    assert ($bits(mst_resp_i.r.id) == AxiMstPortIdWidth);
    end
`endif
`endif
endmodule