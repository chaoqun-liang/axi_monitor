// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Package auto-generated by `reggen` containing data structure

package slv_guard_reg_pkg;

  // Address widths within the block
  parameter int BlockAw = 7;

  ////////////////////////////
  // Typedefs for registers //
  ////////////////////////////

  typedef struct packed {
    logic        q;
  } slv_guard_reg2hw_guard_enable_reg_t;

  typedef struct packed {
    logic [3:0]  q;
  } slv_guard_reg2hw_budget_awvld_awrdy_reg_t;

  typedef struct packed {
    logic [1:0]  q;
  } slv_guard_reg2hw_budget_unit_w_reg_t;

  typedef struct packed {
    logic [3:0]  q;
  } slv_guard_reg2hw_budget_wvld_wrdy_reg_t;

  typedef struct packed {
    logic [3:0]  q;
  } slv_guard_reg2hw_budget_wlast_bvld_reg_t;

  typedef struct packed {
    logic [3:0]  q;
  } slv_guard_reg2hw_budget_bvld_brdy_reg_t;

  typedef struct packed {
    logic [3:0]  q;
  } slv_guard_reg2hw_budget_arvld_arrdy_reg_t;

  typedef struct packed {
    logic [1:0]  q;
  } slv_guard_reg2hw_budget_unit_r_reg_t;

  typedef struct packed {
    logic [3:0]  q;
  } slv_guard_reg2hw_budget_rvld_rrdy_reg_t;

  typedef struct packed {
    logic        q;
  } slv_guard_reg2hw_reset_reg_t;

  typedef struct packed {
    struct packed {
      logic        q;
    } irq;
    struct packed {
      logic        q;
    } w0;
    struct packed {
      logic        q;
    } w1;
    struct packed {
      logic        q;
    } w2;
    struct packed {
      logic        q;
    } w3;
    struct packed {
      logic        q;
    } w4;
    struct packed {
      logic        q;
    } w5;
    struct packed {
      logic        q;
    } r0;
    struct packed {
      logic        q;
    } r1;
    struct packed {
      logic        q;
    } r2;
    struct packed {
      logic        q;
    } r3;
    struct packed {
      logic        q;
    } unwanted_wr_resp;
    struct packed {
      logic        q;
    } unwanted_rd_resp;
    struct packed {
      logic [11:0] q;
    } txn_id;
  } slv_guard_reg2hw_irq_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } slv_guard_reg2hw_irq_addr_reg_t;

  typedef struct packed {
    logic [9:0] q;
  } slv_guard_reg2hw_latency_awvld_awrdy_reg_t;

  typedef struct packed {
    logic [9:0] q;
  } slv_guard_reg2hw_latency_awvld_wfirst_reg_t;

  typedef struct packed {
    logic [9:0] q;
  } slv_guard_reg2hw_latency_wvld_wrdy_reg_t;

  typedef struct packed {
    logic [9:0] q;
  } slv_guard_reg2hw_latency_wvld_wlast_reg_t;

  typedef struct packed {
    logic [9:0] q;
  } slv_guard_reg2hw_latency_wlast_bvld_reg_t;

  typedef struct packed {
    logic [9:0] q;
  } slv_guard_reg2hw_latency_bvld_brdy_reg_t;

  typedef struct packed {
    logic [9:0] q;
  } slv_guard_reg2hw_latency_arvld_arrdy_reg_t;

  typedef struct packed {
    logic [9:0] q;
  } slv_guard_reg2hw_latency_arvld_rvld_reg_t;

  typedef struct packed {
    logic [9:0] q;
  } slv_guard_reg2hw_latency_rvld_rrdy_reg_t;

  typedef struct packed {
    logic [9:0] q;
  } slv_guard_reg2hw_latency_rvld_rlast_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } slv_guard_hw2reg_guard_enable_reg_t;

  typedef struct packed {
    logic [3:0]  d;
    logic        de;
  } slv_guard_hw2reg_budget_awvld_awrdy_reg_t;

  typedef struct packed {
    logic [1:0]  d;
    logic        de;
  } slv_guard_hw2reg_budget_unit_w_reg_t;

  typedef struct packed {
    logic [3:0]  d;
    logic        de;
  } slv_guard_hw2reg_budget_wvld_wrdy_reg_t;

  typedef struct packed {
    logic [3:0]  d;
    logic        de;
  } slv_guard_hw2reg_budget_wlast_bvld_reg_t;

  typedef struct packed {
    logic [3:0]  d;
    logic        de;
  } slv_guard_hw2reg_budget_bvld_brdy_reg_t;

  typedef struct packed {
    logic [3:0]  d;
    logic        de;
  } slv_guard_hw2reg_budget_arvld_arrdy_reg_t;

  typedef struct packed {
    logic [1:0]  d;
    logic        de;
  } slv_guard_hw2reg_budget_unit_r_reg_t;

  typedef struct packed {
    logic [3:0]  d;
    logic        de;
  } slv_guard_hw2reg_budget_rvld_rrdy_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } slv_guard_hw2reg_reset_reg_t;

  typedef struct packed {
    struct packed {
      logic        d;
      logic        de;
    } irq;
    struct packed {
      logic        d;
      logic        de;
    } w0;
    struct packed {
      logic        d;
      logic        de;
    } w1;
    struct packed {
      logic        d;
      logic        de;
    } w2;
    struct packed {
      logic        d;
      logic        de;
    } w3;
    struct packed {
      logic        d;
      logic        de;
    } w4;
    struct packed {
      logic        d;
      logic        de;
    } w5;
    struct packed {
      logic        d;
      logic        de;
    } r0;
    struct packed {
      logic        d;
      logic        de;
    } r1;
    struct packed {
      logic        d;
      logic        de;
    } r2;
    struct packed {
      logic        d;
      logic        de;
    } r3;
    struct packed {
      logic        d;
      logic        de;
    } unwanted_wr_resp;
    struct packed {
      logic        d;
      logic        de;
    } unwanted_rd_resp;
    struct packed {
      logic [11:0] d;
      logic        de;
    } txn_id;
  } slv_guard_hw2reg_irq_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } slv_guard_hw2reg_irq_addr_reg_t;

  typedef struct packed {
    logic [9:0] d;
    logic        de;
  } slv_guard_hw2reg_latency_awvld_awrdy_reg_t;

  typedef struct packed {
    logic [9:0] d;
    logic        de;
  } slv_guard_hw2reg_latency_awvld_wfirst_reg_t;

  typedef struct packed {
    logic [9:0] d;
    logic        de;
  } slv_guard_hw2reg_latency_wvld_wrdy_reg_t;

  typedef struct packed {
    logic [9:0] d;
    logic        de;
  } slv_guard_hw2reg_latency_wvld_wlast_reg_t;

  typedef struct packed {
    logic [9:0] d;
    logic        de;
  } slv_guard_hw2reg_latency_wlast_bvld_reg_t;

  typedef struct packed {
    logic [9:0] d;
    logic        de;
  } slv_guard_hw2reg_latency_bvld_brdy_reg_t;

  typedef struct packed {
    logic [9:0] d;
    logic        de;
  } slv_guard_hw2reg_latency_arvld_arrdy_reg_t;

  typedef struct packed {
    logic [9:0] d;
    logic        de;
  } slv_guard_hw2reg_latency_arvld_rvld_reg_t;

  typedef struct packed {
    logic [9:0] d;
    logic        de;
  } slv_guard_hw2reg_latency_rvld_rrdy_reg_t;

  typedef struct packed {
    logic [9:0] d;
    logic        de;
  } slv_guard_hw2reg_latency_rvld_rlast_reg_t;

  // Register -> HW type
  typedef struct packed {
    slv_guard_reg2hw_guard_enable_reg_t guard_enable; // [186:186]
    slv_guard_reg2hw_budget_awvld_awrdy_reg_t budget_awvld_awrdy; // [185:182]
    slv_guard_reg2hw_budget_unit_w_reg_t budget_unit_w; // [181:180]
    slv_guard_reg2hw_budget_wvld_wrdy_reg_t budget_wvld_wrdy; // [179:176]
    slv_guard_reg2hw_budget_wlast_bvld_reg_t budget_wlast_bvld; // [175:172]
    slv_guard_reg2hw_budget_bvld_brdy_reg_t budget_bvld_brdy; // [171:168]
    slv_guard_reg2hw_budget_arvld_arrdy_reg_t budget_arvld_arrdy; // [167:164]
    slv_guard_reg2hw_budget_unit_r_reg_t budget_unit_r; // [163:162]
    slv_guard_reg2hw_budget_rvld_rrdy_reg_t budget_rvld_rrdy; // [161:158]
    slv_guard_reg2hw_reset_reg_t reset; // [157:157]
    slv_guard_reg2hw_irq_reg_t irq; // [156:132]
    slv_guard_reg2hw_irq_addr_reg_t irq_addr; // [131:100]
    slv_guard_reg2hw_latency_awvld_awrdy_reg_t latency_awvld_awrdy; // [99:90]
    slv_guard_reg2hw_latency_awvld_wfirst_reg_t latency_awvld_wfirst; // [89:80]
    slv_guard_reg2hw_latency_wvld_wrdy_reg_t latency_wvld_wrdy; // [79:70]
    slv_guard_reg2hw_latency_wvld_wlast_reg_t latency_wvld_wlast; // [69:60]
    slv_guard_reg2hw_latency_wlast_bvld_reg_t latency_wlast_bvld; // [59:50]
    slv_guard_reg2hw_latency_bvld_brdy_reg_t latency_bvld_brdy; // [49:40]
    slv_guard_reg2hw_latency_arvld_arrdy_reg_t latency_arvld_arrdy; // [39:30]
    slv_guard_reg2hw_latency_arvld_rvld_reg_t latency_arvld_rvld; // [29:20]
    slv_guard_reg2hw_latency_rvld_rrdy_reg_t latency_rvld_rrdy; // [19:10]
    slv_guard_reg2hw_latency_rvld_rlast_reg_t latency_rvld_rlast; // [9:0]
  } slv_guard_reg2hw_t;

  // HW -> register type
  typedef struct packed {
    slv_guard_hw2reg_guard_enable_reg_t guard_enable; // [221:220]
    slv_guard_hw2reg_budget_awvld_awrdy_reg_t budget_awvld_awrdy; // [219:215]
    slv_guard_hw2reg_budget_unit_w_reg_t budget_unit_w; // [214:212]
    slv_guard_hw2reg_budget_wvld_wrdy_reg_t budget_wvld_wrdy; // [211:207]
    slv_guard_hw2reg_budget_wlast_bvld_reg_t budget_wlast_bvld; // [206:202]
    slv_guard_hw2reg_budget_bvld_brdy_reg_t budget_bvld_brdy; // [201:197]
    slv_guard_hw2reg_budget_arvld_arrdy_reg_t budget_arvld_arrdy; // [196:192]
    slv_guard_hw2reg_budget_unit_r_reg_t budget_unit_r; // [191:189]
    slv_guard_hw2reg_budget_rvld_rrdy_reg_t budget_rvld_rrdy; // [188:184]
    slv_guard_hw2reg_reset_reg_t reset; // [183:182]
    slv_guard_hw2reg_irq_reg_t irq; // [181:143]
    slv_guard_hw2reg_irq_addr_reg_t irq_addr; // [142:110]
    slv_guard_hw2reg_latency_awvld_awrdy_reg_t latency_awvld_awrdy; // [109:99]
    slv_guard_hw2reg_latency_awvld_wfirst_reg_t latency_awvld_wfirst; // [98:88]
    slv_guard_hw2reg_latency_wvld_wrdy_reg_t latency_wvld_wrdy; // [87:77]
    slv_guard_hw2reg_latency_wvld_wlast_reg_t latency_wvld_wlast; // [76:66]
    slv_guard_hw2reg_latency_wlast_bvld_reg_t latency_wlast_bvld; // [65:55]
    slv_guard_hw2reg_latency_bvld_brdy_reg_t latency_bvld_brdy; // [54:44]
    slv_guard_hw2reg_latency_arvld_arrdy_reg_t latency_arvld_arrdy; // [43:33]
    slv_guard_hw2reg_latency_arvld_rvld_reg_t latency_arvld_rvld; // [32:22]
    slv_guard_hw2reg_latency_rvld_rrdy_reg_t latency_rvld_rrdy; // [21:11]
    slv_guard_hw2reg_latency_rvld_rlast_reg_t latency_rvld_rlast; // [10:0]
  } slv_guard_hw2reg_t;

  // Register offsets
  parameter logic [BlockAw-1:0] SLV_GUARD_GUARD_ENABLE_OFFSET = 7'h 0;
  parameter logic [BlockAw-1:0] SLV_GUARD_BUDGET_AWVLD_AWRDY_OFFSET = 7'h 4;
  parameter logic [BlockAw-1:0] SLV_GUARD_BUDGET_UNIT_W_OFFSET = 7'h 8;
  parameter logic [BlockAw-1:0] SLV_GUARD_BUDGET_WVLD_WRDY_OFFSET = 7'h c;
  parameter logic [BlockAw-1:0] SLV_GUARD_BUDGET_WLAST_BVLD_OFFSET = 7'h 10;
  parameter logic [BlockAw-1:0] SLV_GUARD_BUDGET_BVLD_BRDY_OFFSET = 7'h 14;
  parameter logic [BlockAw-1:0] SLV_GUARD_BUDGET_ARVLD_ARRDY_OFFSET = 7'h 18;
  parameter logic [BlockAw-1:0] SLV_GUARD_BUDGET_UNIT_R_OFFSET = 7'h 1c;
  parameter logic [BlockAw-1:0] SLV_GUARD_BUDGET_RVLD_RRDY_OFFSET = 7'h 20;
  parameter logic [BlockAw-1:0] SLV_GUARD_RESET_OFFSET = 7'h 24;
  parameter logic [BlockAw-1:0] SLV_GUARD_IRQ_OFFSET = 7'h 28;
  parameter logic [BlockAw-1:0] SLV_GUARD_IRQ_ADDR_OFFSET = 7'h 2c;
  parameter logic [BlockAw-1:0] SLV_GUARD_LATENCY_AWVLD_AWRDY_OFFSET = 7'h 30;
  parameter logic [BlockAw-1:0] SLV_GUARD_LATENCY_AWVLD_WFIRST_OFFSET = 7'h 34;
  parameter logic [BlockAw-1:0] SLV_GUARD_LATENCY_WVLD_WRDY_OFFSET = 7'h 38;
  parameter logic [BlockAw-1:0] SLV_GUARD_LATENCY_WVLD_WLAST_OFFSET = 7'h 3c;
  parameter logic [BlockAw-1:0] SLV_GUARD_LATENCY_WLAST_BVLD_OFFSET = 7'h 40;
  parameter logic [BlockAw-1:0] SLV_GUARD_LATENCY_BVLD_BRDY_OFFSET = 7'h 44;
  parameter logic [BlockAw-1:0] SLV_GUARD_LATENCY_ARVLD_ARRDY_OFFSET = 7'h 48;
  parameter logic [BlockAw-1:0] SLV_GUARD_LATENCY_ARVLD_RVLD_OFFSET = 7'h 4c;
  parameter logic [BlockAw-1:0] SLV_GUARD_LATENCY_RVLD_RRDY_OFFSET = 7'h 50;
  parameter logic [BlockAw-1:0] SLV_GUARD_LATENCY_RVLD_RLAST_OFFSET = 7'h 54;

  // Register index
  typedef enum int {
    SLV_GUARD_GUARD_ENABLE,
    SLV_GUARD_BUDGET_AWVLD_AWRDY,
    SLV_GUARD_BUDGET_UNIT_W,
    SLV_GUARD_BUDGET_WVLD_WRDY,
    SLV_GUARD_BUDGET_WLAST_BVLD,
    SLV_GUARD_BUDGET_BVLD_BRDY,
    SLV_GUARD_BUDGET_ARVLD_ARRDY,
    SLV_GUARD_BUDGET_UNIT_R,
    SLV_GUARD_BUDGET_RVLD_RRDY,
    SLV_GUARD_RESET,
    SLV_GUARD_IRQ,
    SLV_GUARD_IRQ_ADDR,
    SLV_GUARD_LATENCY_AWVLD_AWRDY,
    SLV_GUARD_LATENCY_AWVLD_WFIRST,
    SLV_GUARD_LATENCY_WVLD_WRDY,
    SLV_GUARD_LATENCY_WVLD_WLAST,
    SLV_GUARD_LATENCY_WLAST_BVLD,
    SLV_GUARD_LATENCY_BVLD_BRDY,
    SLV_GUARD_LATENCY_ARVLD_ARRDY,
    SLV_GUARD_LATENCY_ARVLD_RVLD,
    SLV_GUARD_LATENCY_RVLD_RRDY,
    SLV_GUARD_LATENCY_RVLD_RLAST
  } slv_guard_id_e;

  // Register width information to check illegal writes
  parameter logic [3:0] SLV_GUARD_PERMIT [22] = '{
    4'b 0001, // index[ 0] SLV_GUARD_GUARD_ENABLE
    4'b 0001, // index[ 1] SLV_GUARD_BUDGET_AWVLD_AWRDY
    4'b 0001, // index[ 2] SLV_GUARD_BUDGET_UNIT_W
    4'b 0001, // index[ 3] SLV_GUARD_BUDGET_WVLD_WRDY
    4'b 0001, // index[ 4] SLV_GUARD_BUDGET_WLAST_BVLD
    4'b 0001, // index[ 5] SLV_GUARD_BUDGET_BVLD_BRDY
    4'b 0001, // index[ 6] SLV_GUARD_BUDGET_ARVLD_ARRDY
    4'b 0001, // index[ 7] SLV_GUARD_BUDGET_UNIT_R
    4'b 0001, // index[ 8] SLV_GUARD_BUDGET_RVLD_RRDY
    4'b 0001, // index[ 9] SLV_GUARD_RESET
    4'b 1111, // index[10] SLV_GUARD_IRQ
    4'b 1111, // index[11] SLV_GUARD_IRQ_ADDR
    4'b 0011, // index[12] SLV_GUARD_LATENCY_AWVLD_AWRDY
    4'b 0011, // index[13] SLV_GUARD_LATENCY_AWVLD_WFIRST
    4'b 0011, // index[14] SLV_GUARD_LATENCY_WVLD_WRDY
    4'b 0011, // index[15] SLV_GUARD_LATENCY_WVLD_WLAST
    4'b 0011, // index[16] SLV_GUARD_LATENCY_WLAST_BVLD
    4'b 0011, // index[17] SLV_GUARD_LATENCY_BVLD_BRDY
    4'b 0011, // index[18] SLV_GUARD_LATENCY_ARVLD_ARRDY
    4'b 0011, // index[19] SLV_GUARD_LATENCY_ARVLD_RVLD
    4'b 0011, // index[20] SLV_GUARD_LATENCY_RVLD_RRDY
    4'b 0011  // index[21] SLV_GUARD_LATENCY_RVLD_RLAST
  };

endpackage

