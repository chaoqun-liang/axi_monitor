// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Top module auto-generated by `reggen`


`include "common_cells/assertions.svh"

module slv_guard_reg_top #(
  parameter type reg_req_t = logic,
  parameter type reg_rsp_t = logic,
  parameter int AW = 7
) (
  input logic clk_i,
  input logic rst_ni,
  input  reg_req_t reg_req_i,
  output reg_rsp_t reg_rsp_o,
  // To HW
  output slv_guard_reg_pkg::slv_guard_reg2hw_t reg2hw, // Write
  input  slv_guard_reg_pkg::slv_guard_hw2reg_t hw2reg, // Read


  // Config
  input devmode_i // If 1, explicit error return for unmapped register access
);

  import slv_guard_reg_pkg::* ;

  localparam int DW = 32;
  localparam int DBW = DW/8;                    // Byte Width

  // register signals
  logic           reg_we;
  logic           reg_re;
  logic [BlockAw-1:0]  reg_addr;
  logic [DW-1:0]  reg_wdata;
  logic [DBW-1:0] reg_be;
  logic [DW-1:0]  reg_rdata;
  logic           reg_error;

  logic          addrmiss, wr_err;

  logic [DW-1:0] reg_rdata_next;

  // Below register interface can be changed
  reg_req_t  reg_intf_req;
  reg_rsp_t  reg_intf_rsp;


  assign reg_intf_req = reg_req_i;
  assign reg_rsp_o = reg_intf_rsp;


  assign reg_we = reg_intf_req.valid & reg_intf_req.write;
  assign reg_re = reg_intf_req.valid & ~reg_intf_req.write;
  assign reg_addr = reg_intf_req.addr[BlockAw-1:0];
  assign reg_wdata = reg_intf_req.wdata;
  assign reg_be = reg_intf_req.wstrb;
  assign reg_intf_rsp.rdata = reg_rdata;
  assign reg_intf_rsp.error = reg_error;
  assign reg_intf_rsp.ready = 1'b1;

  assign reg_rdata = reg_rdata_next ;
  assign reg_error = (devmode_i & addrmiss) | wr_err;


  // Define SW related signals
  // Format: <reg>_<field>_{wd|we|qs}
  //        or <reg>_{wd|we|qs} if field == 1 or 0
  logic guard_enable_qs;
  logic guard_enable_wd;
  logic guard_enable_we;
  logic [3:0] budget_awvld_awrdy_wd;
  logic budget_awvld_awrdy_we;
  logic [1:0] budget_unit_w_wd;
  logic budget_unit_w_we;
  logic [3:0] budget_wvld_wrdy_wd;
  logic budget_wvld_wrdy_we;
  logic [3:0] budget_wlast_bvld_wd;
  logic budget_wlast_bvld_we;
  logic [3:0] budget_bvld_brdy_wd;
  logic budget_bvld_brdy_we;
  logic [3:0] budget_arvld_arrdy_wd;
  logic budget_arvld_arrdy_we;
  logic [1:0] budget_unit_r_wd;
  logic budget_unit_r_we;
  logic [3:0] budget_rvld_rrdy_wd;
  logic budget_rvld_rrdy_we;
  logic reset_qs;
  logic irq_irq_qs;
  logic irq_irq_wd;
  logic irq_irq_we;
  logic irq_w0_qs;
  logic irq_w0_wd;
  logic irq_w0_we;
  logic irq_w1_qs;
  logic irq_w1_wd;
  logic irq_w1_we;
  logic irq_w2_qs;
  logic irq_w2_wd;
  logic irq_w2_we;
  logic irq_w3_qs;
  logic irq_w3_wd;
  logic irq_w3_we;
  logic irq_w4_qs;
  logic irq_w4_wd;
  logic irq_w4_we;
  logic irq_w5_qs;
  logic irq_w5_wd;
  logic irq_w5_we;
  logic irq_r0_qs;
  logic irq_r0_wd;
  logic irq_r0_we;
  logic irq_r1_qs;
  logic irq_r1_wd;
  logic irq_r1_we;
  logic irq_r2_qs;
  logic irq_r2_wd;
  logic irq_r2_we;
  logic irq_r3_qs;
  logic irq_r3_wd;
  logic irq_r3_we;
  logic irq_unwanted_wr_resp_qs;
  logic irq_unwanted_wr_resp_wd;
  logic irq_unwanted_wr_resp_we;
  logic irq_unwanted_rd_resp_qs;
  logic irq_unwanted_rd_resp_wd;
  logic irq_unwanted_rd_resp_we;
  logic [11:0] irq_txn_id_qs;
  logic [11:0] irq_txn_id_wd;
  logic irq_txn_id_we;
  logic [31:0] irq_addr_qs;
  logic [9:0] latency_awvld_awrdy_qs;
  logic [9:0] latency_awvld_wfirst_qs;
  logic [9:0] latency_wvld_wrdy_qs;
  logic [9:0] latency_wvld_wlast_qs;
  logic [9:0] latency_wlast_bvld_qs;
  logic [9:0] latency_bvld_brdy_qs;
  logic [9:0] latency_arvld_arrdy_qs;
  logic [9:0] latency_arvld_rvld_qs;
  logic [9:0] latency_rvld_rrdy_qs;
  logic [9:0] latency_rvld_rlast_qs;

  // Register instances
  // R[guard_enable]: V(False)

  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_guard_enable (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (guard_enable_we),
    .wd     (guard_enable_wd),

    // from internal hardware
    .de     (hw2reg.guard_enable.de),
    .d      (hw2reg.guard_enable.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.guard_enable.q ),

    // to register interface (read)
    .qs     (guard_enable_qs)
  );


  // R[budget_awvld_awrdy]: V(False)

  prim_subreg #(
    .DW      (4),
    .SWACCESS("WO"),
    .RESVAL  (4'h0)
  ) u_budget_awvld_awrdy (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (budget_awvld_awrdy_we),
    .wd     (budget_awvld_awrdy_wd),

    // from internal hardware
    .de     (hw2reg.budget_awvld_awrdy.de),
    .d      (hw2reg.budget_awvld_awrdy.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.budget_awvld_awrdy.q ),

    .qs     ()
  );


  // R[budget_unit_w]: V(False)

  prim_subreg #(
    .DW      (2),
    .SWACCESS("WO"),
    .RESVAL  (2'h0)
  ) u_budget_unit_w (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (budget_unit_w_we),
    .wd     (budget_unit_w_wd),

    // from internal hardware
    .de     (hw2reg.budget_unit_w.de),
    .d      (hw2reg.budget_unit_w.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.budget_unit_w.q ),

    .qs     ()
  );


  // R[budget_wvld_wrdy]: V(False)

  prim_subreg #(
    .DW      (4),
    .SWACCESS("WO"),
    .RESVAL  (4'h0)
  ) u_budget_wvld_wrdy (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (budget_wvld_wrdy_we),
    .wd     (budget_wvld_wrdy_wd),

    // from internal hardware
    .de     (hw2reg.budget_wvld_wrdy.de),
    .d      (hw2reg.budget_wvld_wrdy.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.budget_wvld_wrdy.q ),

    .qs     ()
  );


  // R[budget_wlast_bvld]: V(False)

  prim_subreg #(
    .DW      (4),
    .SWACCESS("WO"),
    .RESVAL  (4'h0)
  ) u_budget_wlast_bvld (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (budget_wlast_bvld_we),
    .wd     (budget_wlast_bvld_wd),

    // from internal hardware
    .de     (hw2reg.budget_wlast_bvld.de),
    .d      (hw2reg.budget_wlast_bvld.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.budget_wlast_bvld.q ),

    .qs     ()
  );


  // R[budget_bvld_brdy]: V(False)

  prim_subreg #(
    .DW      (4),
    .SWACCESS("WO"),
    .RESVAL  (4'h0)
  ) u_budget_bvld_brdy (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (budget_bvld_brdy_we),
    .wd     (budget_bvld_brdy_wd),

    // from internal hardware
    .de     (hw2reg.budget_bvld_brdy.de),
    .d      (hw2reg.budget_bvld_brdy.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.budget_bvld_brdy.q ),

    .qs     ()
  );


  // R[budget_arvld_arrdy]: V(False)

  prim_subreg #(
    .DW      (4),
    .SWACCESS("WO"),
    .RESVAL  (4'h0)
  ) u_budget_arvld_arrdy (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (budget_arvld_arrdy_we),
    .wd     (budget_arvld_arrdy_wd),

    // from internal hardware
    .de     (hw2reg.budget_arvld_arrdy.de),
    .d      (hw2reg.budget_arvld_arrdy.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.budget_arvld_arrdy.q ),

    .qs     ()
  );


  // R[budget_unit_r]: V(False)

  prim_subreg #(
    .DW      (2),
    .SWACCESS("WO"),
    .RESVAL  (2'h0)
  ) u_budget_unit_r (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (budget_unit_r_we),
    .wd     (budget_unit_r_wd),

    // from internal hardware
    .de     (hw2reg.budget_unit_r.de),
    .d      (hw2reg.budget_unit_r.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.budget_unit_r.q ),

    .qs     ()
  );


  // R[budget_rvld_rrdy]: V(False)

  prim_subreg #(
    .DW      (4),
    .SWACCESS("WO"),
    .RESVAL  (4'h0)
  ) u_budget_rvld_rrdy (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (budget_rvld_rrdy_we),
    .wd     (budget_rvld_rrdy_wd),

    // from internal hardware
    .de     (hw2reg.budget_rvld_rrdy.de),
    .d      (hw2reg.budget_rvld_rrdy.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.budget_rvld_rrdy.q ),

    .qs     ()
  );


  // R[reset]: V(False)

  prim_subreg #(
    .DW      (1),
    .SWACCESS("RO"),
    .RESVAL  (1'h0)
  ) u_reset (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.reset.de),
    .d      (hw2reg.reset.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.reset.q ),

    // to register interface (read)
    .qs     (reset_qs)
  );


  // R[irq]: V(False)

  //   F[irq]: 0:0
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_irq_irq (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (irq_irq_we),
    .wd     (irq_irq_wd),

    // from internal hardware
    .de     (hw2reg.irq.irq.de),
    .d      (hw2reg.irq.irq.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq.irq.q ),

    // to register interface (read)
    .qs     (irq_irq_qs)
  );


  //   F[w0]: 1:1
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_irq_w0 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (irq_w0_we),
    .wd     (irq_w0_wd),

    // from internal hardware
    .de     (hw2reg.irq.w0.de),
    .d      (hw2reg.irq.w0.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq.w0.q ),

    // to register interface (read)
    .qs     (irq_w0_qs)
  );


  //   F[w1]: 2:2
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_irq_w1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (irq_w1_we),
    .wd     (irq_w1_wd),

    // from internal hardware
    .de     (hw2reg.irq.w1.de),
    .d      (hw2reg.irq.w1.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq.w1.q ),

    // to register interface (read)
    .qs     (irq_w1_qs)
  );


  //   F[w2]: 3:3
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_irq_w2 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (irq_w2_we),
    .wd     (irq_w2_wd),

    // from internal hardware
    .de     (hw2reg.irq.w2.de),
    .d      (hw2reg.irq.w2.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq.w2.q ),

    // to register interface (read)
    .qs     (irq_w2_qs)
  );


  //   F[w3]: 4:4
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_irq_w3 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (irq_w3_we),
    .wd     (irq_w3_wd),

    // from internal hardware
    .de     (hw2reg.irq.w3.de),
    .d      (hw2reg.irq.w3.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq.w3.q ),

    // to register interface (read)
    .qs     (irq_w3_qs)
  );


  //   F[w4]: 5:5
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_irq_w4 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (irq_w4_we),
    .wd     (irq_w4_wd),

    // from internal hardware
    .de     (hw2reg.irq.w4.de),
    .d      (hw2reg.irq.w4.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq.w4.q ),

    // to register interface (read)
    .qs     (irq_w4_qs)
  );


  //   F[w5]: 6:6
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_irq_w5 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (irq_w5_we),
    .wd     (irq_w5_wd),

    // from internal hardware
    .de     (hw2reg.irq.w5.de),
    .d      (hw2reg.irq.w5.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq.w5.q ),

    // to register interface (read)
    .qs     (irq_w5_qs)
  );


  //   F[r0]: 7:7
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_irq_r0 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (irq_r0_we),
    .wd     (irq_r0_wd),

    // from internal hardware
    .de     (hw2reg.irq.r0.de),
    .d      (hw2reg.irq.r0.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq.r0.q ),

    // to register interface (read)
    .qs     (irq_r0_qs)
  );


  //   F[r1]: 8:8
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_irq_r1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (irq_r1_we),
    .wd     (irq_r1_wd),

    // from internal hardware
    .de     (hw2reg.irq.r1.de),
    .d      (hw2reg.irq.r1.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq.r1.q ),

    // to register interface (read)
    .qs     (irq_r1_qs)
  );


  //   F[r2]: 9:9
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_irq_r2 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (irq_r2_we),
    .wd     (irq_r2_wd),

    // from internal hardware
    .de     (hw2reg.irq.r2.de),
    .d      (hw2reg.irq.r2.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq.r2.q ),

    // to register interface (read)
    .qs     (irq_r2_qs)
  );


  //   F[r3]: 10:10
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_irq_r3 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (irq_r3_we),
    .wd     (irq_r3_wd),

    // from internal hardware
    .de     (hw2reg.irq.r3.de),
    .d      (hw2reg.irq.r3.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq.r3.q ),

    // to register interface (read)
    .qs     (irq_r3_qs)
  );


  //   F[unwanted_wr_resp]: 11:11
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_irq_unwanted_wr_resp (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (irq_unwanted_wr_resp_we),
    .wd     (irq_unwanted_wr_resp_wd),

    // from internal hardware
    .de     (hw2reg.irq.unwanted_wr_resp.de),
    .d      (hw2reg.irq.unwanted_wr_resp.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq.unwanted_wr_resp.q ),

    // to register interface (read)
    .qs     (irq_unwanted_wr_resp_qs)
  );


  //   F[unwanted_rd_resp]: 12:12
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_irq_unwanted_rd_resp (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (irq_unwanted_rd_resp_we),
    .wd     (irq_unwanted_rd_resp_wd),

    // from internal hardware
    .de     (hw2reg.irq.unwanted_rd_resp.de),
    .d      (hw2reg.irq.unwanted_rd_resp.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq.unwanted_rd_resp.q ),

    // to register interface (read)
    .qs     (irq_unwanted_rd_resp_qs)
  );


  //   F[txn_id]: 24:13
  prim_subreg #(
    .DW      (12),
    .SWACCESS("RW"),
    .RESVAL  (12'h0)
  ) u_irq_txn_id (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (irq_txn_id_we),
    .wd     (irq_txn_id_wd),

    // from internal hardware
    .de     (hw2reg.irq.txn_id.de),
    .d      (hw2reg.irq.txn_id.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq.txn_id.q ),

    // to register interface (read)
    .qs     (irq_txn_id_qs)
  );


  // R[irq_addr]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RO"),
    .RESVAL  (32'h0)
  ) u_irq_addr (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.irq_addr.de),
    .d      (hw2reg.irq_addr.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.irq_addr.q ),

    // to register interface (read)
    .qs     (irq_addr_qs)
  );


  // R[latency_awvld_awrdy]: V(False)

  prim_subreg #(
    .DW      (10),
    .SWACCESS("RO"),
    .RESVAL  (10'h0)
  ) u_latency_awvld_awrdy (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.latency_awvld_awrdy.de),
    .d      (hw2reg.latency_awvld_awrdy.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.latency_awvld_awrdy.q ),

    // to register interface (read)
    .qs     (latency_awvld_awrdy_qs)
  );


  // R[latency_awvld_wfirst]: V(False)

  prim_subreg #(
    .DW      (10),
    .SWACCESS("RO"),
    .RESVAL  (10'h0)
  ) u_latency_awvld_wfirst (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.latency_awvld_wfirst.de),
    .d      (hw2reg.latency_awvld_wfirst.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.latency_awvld_wfirst.q ),

    // to register interface (read)
    .qs     (latency_awvld_wfirst_qs)
  );


  // R[latency_wvld_wrdy]: V(False)

  prim_subreg #(
    .DW      (10),
    .SWACCESS("RO"),
    .RESVAL  (10'h0)
  ) u_latency_wvld_wrdy (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.latency_wvld_wrdy.de),
    .d      (hw2reg.latency_wvld_wrdy.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.latency_wvld_wrdy.q ),

    // to register interface (read)
    .qs     (latency_wvld_wrdy_qs)
  );


  // R[latency_wvld_wlast]: V(False)

  prim_subreg #(
    .DW      (10),
    .SWACCESS("RO"),
    .RESVAL  (10'h0)
  ) u_latency_wvld_wlast (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.latency_wvld_wlast.de),
    .d      (hw2reg.latency_wvld_wlast.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.latency_wvld_wlast.q ),

    // to register interface (read)
    .qs     (latency_wvld_wlast_qs)
  );


  // R[latency_wlast_bvld]: V(False)

  prim_subreg #(
    .DW      (10),
    .SWACCESS("RO"),
    .RESVAL  (10'h0)
  ) u_latency_wlast_bvld (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.latency_wlast_bvld.de),
    .d      (hw2reg.latency_wlast_bvld.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.latency_wlast_bvld.q ),

    // to register interface (read)
    .qs     (latency_wlast_bvld_qs)
  );


  // R[latency_bvld_brdy]: V(False)

  prim_subreg #(
    .DW      (10),
    .SWACCESS("RO"),
    .RESVAL  (10'h0)
  ) u_latency_bvld_brdy (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.latency_bvld_brdy.de),
    .d      (hw2reg.latency_bvld_brdy.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.latency_bvld_brdy.q ),

    // to register interface (read)
    .qs     (latency_bvld_brdy_qs)
  );


  // R[latency_arvld_arrdy]: V(False)

  prim_subreg #(
    .DW      (10),
    .SWACCESS("RO"),
    .RESVAL  (10'h0)
  ) u_latency_arvld_arrdy (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.latency_arvld_arrdy.de),
    .d      (hw2reg.latency_arvld_arrdy.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.latency_arvld_arrdy.q ),

    // to register interface (read)
    .qs     (latency_arvld_arrdy_qs)
  );


  // R[latency_arvld_rvld]: V(False)

  prim_subreg #(
    .DW      (10),
    .SWACCESS("RO"),
    .RESVAL  (10'h0)
  ) u_latency_arvld_rvld (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.latency_arvld_rvld.de),
    .d      (hw2reg.latency_arvld_rvld.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.latency_arvld_rvld.q ),

    // to register interface (read)
    .qs     (latency_arvld_rvld_qs)
  );


  // R[latency_rvld_rrdy]: V(False)

  prim_subreg #(
    .DW      (10),
    .SWACCESS("RO"),
    .RESVAL  (10'h0)
  ) u_latency_rvld_rrdy (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.latency_rvld_rrdy.de),
    .d      (hw2reg.latency_rvld_rrdy.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.latency_rvld_rrdy.q ),

    // to register interface (read)
    .qs     (latency_rvld_rrdy_qs)
  );


  // R[latency_rvld_rlast]: V(False)

  prim_subreg #(
    .DW      (10),
    .SWACCESS("RO"),
    .RESVAL  (10'h0)
  ) u_latency_rvld_rlast (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.latency_rvld_rlast.de),
    .d      (hw2reg.latency_rvld_rlast.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.latency_rvld_rlast.q ),

    // to register interface (read)
    .qs     (latency_rvld_rlast_qs)
  );




  logic [21:0] addr_hit;
  always_comb begin
    addr_hit = '0;
    addr_hit[ 0] = (reg_addr == SLV_GUARD_GUARD_ENABLE_OFFSET);
    addr_hit[ 1] = (reg_addr == SLV_GUARD_BUDGET_AWVLD_AWRDY_OFFSET);
    addr_hit[ 2] = (reg_addr == SLV_GUARD_BUDGET_UNIT_W_OFFSET);
    addr_hit[ 3] = (reg_addr == SLV_GUARD_BUDGET_WVLD_WRDY_OFFSET);
    addr_hit[ 4] = (reg_addr == SLV_GUARD_BUDGET_WLAST_BVLD_OFFSET);
    addr_hit[ 5] = (reg_addr == SLV_GUARD_BUDGET_BVLD_BRDY_OFFSET);
    addr_hit[ 6] = (reg_addr == SLV_GUARD_BUDGET_ARVLD_ARRDY_OFFSET);
    addr_hit[ 7] = (reg_addr == SLV_GUARD_BUDGET_UNIT_R_OFFSET);
    addr_hit[ 8] = (reg_addr == SLV_GUARD_BUDGET_RVLD_RRDY_OFFSET);
    addr_hit[ 9] = (reg_addr == SLV_GUARD_RESET_OFFSET);
    addr_hit[10] = (reg_addr == SLV_GUARD_IRQ_OFFSET);
    addr_hit[11] = (reg_addr == SLV_GUARD_IRQ_ADDR_OFFSET);
    addr_hit[12] = (reg_addr == SLV_GUARD_LATENCY_AWVLD_AWRDY_OFFSET);
    addr_hit[13] = (reg_addr == SLV_GUARD_LATENCY_AWVLD_WFIRST_OFFSET);
    addr_hit[14] = (reg_addr == SLV_GUARD_LATENCY_WVLD_WRDY_OFFSET);
    addr_hit[15] = (reg_addr == SLV_GUARD_LATENCY_WVLD_WLAST_OFFSET);
    addr_hit[16] = (reg_addr == SLV_GUARD_LATENCY_WLAST_BVLD_OFFSET);
    addr_hit[17] = (reg_addr == SLV_GUARD_LATENCY_BVLD_BRDY_OFFSET);
    addr_hit[18] = (reg_addr == SLV_GUARD_LATENCY_ARVLD_ARRDY_OFFSET);
    addr_hit[19] = (reg_addr == SLV_GUARD_LATENCY_ARVLD_RVLD_OFFSET);
    addr_hit[20] = (reg_addr == SLV_GUARD_LATENCY_RVLD_RRDY_OFFSET);
    addr_hit[21] = (reg_addr == SLV_GUARD_LATENCY_RVLD_RLAST_OFFSET);
  end

  assign addrmiss = (reg_re || reg_we) ? ~|addr_hit : 1'b0 ;

  // Check sub-word write is permitted
  always_comb begin
    wr_err = (reg_we &
              ((addr_hit[ 0] & (|(SLV_GUARD_PERMIT[ 0] & ~reg_be))) |
               (addr_hit[ 1] & (|(SLV_GUARD_PERMIT[ 1] & ~reg_be))) |
               (addr_hit[ 2] & (|(SLV_GUARD_PERMIT[ 2] & ~reg_be))) |
               (addr_hit[ 3] & (|(SLV_GUARD_PERMIT[ 3] & ~reg_be))) |
               (addr_hit[ 4] & (|(SLV_GUARD_PERMIT[ 4] & ~reg_be))) |
               (addr_hit[ 5] & (|(SLV_GUARD_PERMIT[ 5] & ~reg_be))) |
               (addr_hit[ 6] & (|(SLV_GUARD_PERMIT[ 6] & ~reg_be))) |
               (addr_hit[ 7] & (|(SLV_GUARD_PERMIT[ 7] & ~reg_be))) |
               (addr_hit[ 8] & (|(SLV_GUARD_PERMIT[ 8] & ~reg_be))) |
               (addr_hit[ 9] & (|(SLV_GUARD_PERMIT[ 9] & ~reg_be))) |
               (addr_hit[10] & (|(SLV_GUARD_PERMIT[10] & ~reg_be))) |
               (addr_hit[11] & (|(SLV_GUARD_PERMIT[11] & ~reg_be))) |
               (addr_hit[12] & (|(SLV_GUARD_PERMIT[12] & ~reg_be))) |
               (addr_hit[13] & (|(SLV_GUARD_PERMIT[13] & ~reg_be))) |
               (addr_hit[14] & (|(SLV_GUARD_PERMIT[14] & ~reg_be))) |
               (addr_hit[15] & (|(SLV_GUARD_PERMIT[15] & ~reg_be))) |
               (addr_hit[16] & (|(SLV_GUARD_PERMIT[16] & ~reg_be))) |
               (addr_hit[17] & (|(SLV_GUARD_PERMIT[17] & ~reg_be))) |
               (addr_hit[18] & (|(SLV_GUARD_PERMIT[18] & ~reg_be))) |
               (addr_hit[19] & (|(SLV_GUARD_PERMIT[19] & ~reg_be))) |
               (addr_hit[20] & (|(SLV_GUARD_PERMIT[20] & ~reg_be))) |
               (addr_hit[21] & (|(SLV_GUARD_PERMIT[21] & ~reg_be)))));
  end

  assign guard_enable_we = addr_hit[0] & reg_we & !reg_error;
  assign guard_enable_wd = reg_wdata[0];

  assign budget_awvld_awrdy_we = addr_hit[1] & reg_we & !reg_error;
  assign budget_awvld_awrdy_wd = reg_wdata[3:0];

  assign budget_unit_w_we = addr_hit[2] & reg_we & !reg_error;
  assign budget_unit_w_wd = reg_wdata[1:0];

  assign budget_wvld_wrdy_we = addr_hit[3] & reg_we & !reg_error;
  assign budget_wvld_wrdy_wd = reg_wdata[3:0];

  assign budget_wlast_bvld_we = addr_hit[4] & reg_we & !reg_error;
  assign budget_wlast_bvld_wd = reg_wdata[3:0];

  assign budget_bvld_brdy_we = addr_hit[5] & reg_we & !reg_error;
  assign budget_bvld_brdy_wd = reg_wdata[3:0];

  assign budget_arvld_arrdy_we = addr_hit[6] & reg_we & !reg_error;
  assign budget_arvld_arrdy_wd = reg_wdata[3:0];

  assign budget_unit_r_we = addr_hit[7] & reg_we & !reg_error;
  assign budget_unit_r_wd = reg_wdata[1:0];

  assign budget_rvld_rrdy_we = addr_hit[8] & reg_we & !reg_error;
  assign budget_rvld_rrdy_wd = reg_wdata[3:0];

  assign irq_irq_we = addr_hit[10] & reg_we & !reg_error;
  assign irq_irq_wd = reg_wdata[0];

  assign irq_w0_we = addr_hit[10] & reg_we & !reg_error;
  assign irq_w0_wd = reg_wdata[1];

  assign irq_w1_we = addr_hit[10] & reg_we & !reg_error;
  assign irq_w1_wd = reg_wdata[2];

  assign irq_w2_we = addr_hit[10] & reg_we & !reg_error;
  assign irq_w2_wd = reg_wdata[3];

  assign irq_w3_we = addr_hit[10] & reg_we & !reg_error;
  assign irq_w3_wd = reg_wdata[4];

  assign irq_w4_we = addr_hit[10] & reg_we & !reg_error;
  assign irq_w4_wd = reg_wdata[5];

  assign irq_w5_we = addr_hit[10] & reg_we & !reg_error;
  assign irq_w5_wd = reg_wdata[6];

  assign irq_r0_we = addr_hit[10] & reg_we & !reg_error;
  assign irq_r0_wd = reg_wdata[7];

  assign irq_r1_we = addr_hit[10] & reg_we & !reg_error;
  assign irq_r1_wd = reg_wdata[8];

  assign irq_r2_we = addr_hit[10] & reg_we & !reg_error;
  assign irq_r2_wd = reg_wdata[9];

  assign irq_r3_we = addr_hit[10] & reg_we & !reg_error;
  assign irq_r3_wd = reg_wdata[10];

  assign irq_unwanted_wr_resp_we = addr_hit[10] & reg_we & !reg_error;
  assign irq_unwanted_wr_resp_wd = reg_wdata[11];

  assign irq_unwanted_rd_resp_we = addr_hit[10] & reg_we & !reg_error;
  assign irq_unwanted_rd_resp_wd = reg_wdata[12];

  assign irq_txn_id_we = addr_hit[10] & reg_we & !reg_error;
  assign irq_txn_id_wd = reg_wdata[24:13];

  // Read data return
  always_comb begin
    reg_rdata_next = '0;
    unique case (1'b1)
      addr_hit[0]: begin
        reg_rdata_next[0] = guard_enable_qs;
      end

      addr_hit[1]: begin
        reg_rdata_next[3:0] = '0;
      end

      addr_hit[2]: begin
        reg_rdata_next[1:0] = '0;
      end

      addr_hit[3]: begin
        reg_rdata_next[3:0] = '0;
      end

      addr_hit[4]: begin
        reg_rdata_next[3:0] = '0;
      end

      addr_hit[5]: begin
        reg_rdata_next[3:0] = '0;
      end

      addr_hit[6]: begin
        reg_rdata_next[3:0] = '0;
      end

      addr_hit[7]: begin
        reg_rdata_next[1:0] = '0;
      end

      addr_hit[8]: begin
        reg_rdata_next[3:0] = '0;
      end

      addr_hit[9]: begin
        reg_rdata_next[0] = reset_qs;
      end

      addr_hit[10]: begin
        reg_rdata_next[0] = irq_irq_qs;
        reg_rdata_next[1] = irq_w0_qs;
        reg_rdata_next[2] = irq_w1_qs;
        reg_rdata_next[3] = irq_w2_qs;
        reg_rdata_next[4] = irq_w3_qs;
        reg_rdata_next[5] = irq_w4_qs;
        reg_rdata_next[6] = irq_w5_qs;
        reg_rdata_next[7] = irq_r0_qs;
        reg_rdata_next[8] = irq_r1_qs;
        reg_rdata_next[9] = irq_r2_qs;
        reg_rdata_next[10] = irq_r3_qs;
        reg_rdata_next[11] = irq_unwanted_wr_resp_qs;
        reg_rdata_next[12] = irq_unwanted_rd_resp_qs;
        reg_rdata_next[24:13] = irq_txn_id_qs;
      end

      addr_hit[11]: begin
        reg_rdata_next[31:0] = irq_addr_qs;
      end

      addr_hit[12]: begin
        reg_rdata_next[9:0] = latency_awvld_awrdy_qs;
      end

      addr_hit[13]: begin
        reg_rdata_next[9:0] = latency_awvld_wfirst_qs;
      end

      addr_hit[14]: begin
        reg_rdata_next[9:0] = latency_wvld_wrdy_qs;
      end

      addr_hit[15]: begin
        reg_rdata_next[9:0] = latency_wvld_wlast_qs;
      end

      addr_hit[16]: begin
        reg_rdata_next[9:0] = latency_wlast_bvld_qs;
      end

      addr_hit[17]: begin
        reg_rdata_next[9:0] = latency_bvld_brdy_qs;
      end

      addr_hit[18]: begin
        reg_rdata_next[9:0] = latency_arvld_arrdy_qs;
      end

      addr_hit[19]: begin
        reg_rdata_next[9:0] = latency_arvld_rvld_qs;
      end

      addr_hit[20]: begin
        reg_rdata_next[9:0] = latency_rvld_rrdy_qs;
      end

      addr_hit[21]: begin
        reg_rdata_next[9:0] = latency_rvld_rlast_qs;
      end

      default: begin
        reg_rdata_next = '1;
      end
    endcase
  end

  // Unused signal tieoff

  // wdata / byte enable are not always fully used
  // add a blanket unused statement to handle lint waivers
  logic unused_wdata;
  logic unused_be;
  assign unused_wdata = ^reg_wdata;
  assign unused_be = ^reg_be;

  // Assertions for Register Interface
  `ASSERT(en2addrHit, (reg_we || reg_re) |-> $onehot0(addr_hit))

endmodule

module slv_guard_reg_top_intf
#(
  parameter int AW = 7,
  localparam int DW = 32
) (
  input logic clk_i,
  input logic rst_ni,
  REG_BUS.in  regbus_slave,
  // To HW
  output slv_guard_reg_pkg::slv_guard_reg2hw_t reg2hw, // Write
  input  slv_guard_reg_pkg::slv_guard_hw2reg_t hw2reg, // Read
  // Config
  input devmode_i // If 1, explicit error return for unmapped register access
);
 localparam int unsigned STRB_WIDTH = DW/8;

`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"

  // Define structs for reg_bus
  typedef logic [AW-1:0] addr_t;
  typedef logic [DW-1:0] data_t;
  typedef logic [STRB_WIDTH-1:0] strb_t;
  `REG_BUS_TYPEDEF_ALL(reg_bus, addr_t, data_t, strb_t)

  reg_bus_req_t s_reg_req;
  reg_bus_rsp_t s_reg_rsp;
  
  // Assign SV interface to structs
  `REG_BUS_ASSIGN_TO_REQ(s_reg_req, regbus_slave)
  `REG_BUS_ASSIGN_FROM_RSP(regbus_slave, s_reg_rsp)

  

  slv_guard_reg_top #(
    .reg_req_t(reg_bus_req_t),
    .reg_rsp_t(reg_bus_rsp_t),
    .AW(AW)
  ) i_regs (
    .clk_i,
    .rst_ni,
    .reg_req_i(s_reg_req),
    .reg_rsp_o(s_reg_rsp),
    .reg2hw, // Write
    .hw2reg, // Read
    .devmode_i
  );
  
endmodule


