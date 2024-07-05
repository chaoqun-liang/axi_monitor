// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Package auto-generated by `reggen` containing data structure

package slv_guard_reg_pkg;

  // Address widths within the block
  parameter int BlockAw = 5;

  ////////////////////////////
  // Typedefs for registers //
  ////////////////////////////

  typedef struct packed {
    logic        q;
  } slv_guard_reg2hw_guard_enable_reg_t;

  typedef struct packed {
    logic [19:0] q;
  } slv_guard_reg2hw_budget_write_reg_t;

  typedef struct packed {
    logic [19:0] q;
  } slv_guard_reg2hw_budget_read_reg_t;

  typedef struct packed {
    logic        q;
  } slv_guard_reg2hw_reset_reg_t;

  typedef struct packed {
    struct packed {
      logic        q;
    } write;
    struct packed {
      logic        q;
    } read;
    struct packed {
      logic        q;
    } mis_id_wr;
    struct packed {
      logic        q;
    } mis_id_rd;
    struct packed {
      logic        q;
    } unwanted_txn;
    struct packed {
      logic [11:0] q;
    } txn_id;
  } slv_guard_reg2hw_irq_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } slv_guard_reg2hw_irq_addr_reg_t;

  typedef struct packed {
    logic [9:0] q;
  } slv_guard_reg2hw_latency_write_reg_t;

  typedef struct packed {
    logic [9:0] q;
  } slv_guard_reg2hw_latency_read_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } slv_guard_hw2reg_guard_enable_reg_t;

  typedef struct packed {
    logic [19:0] d;
    logic        de;
  } slv_guard_hw2reg_budget_write_reg_t;

  typedef struct packed {
    logic [19:0] d;
    logic        de;
  } slv_guard_hw2reg_budget_read_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } slv_guard_hw2reg_reset_reg_t;

  typedef struct packed {
    struct packed {
      logic        d;
      logic        de;
    } write;
    struct packed {
      logic        d;
      logic        de;
    } read;
    struct packed {
      logic        d;
      logic        de;
    } mis_id_wr;
    struct packed {
      logic        d;
      logic        de;
    } mis_id_rd;
    struct packed {
      logic        d;
      logic        de;
    } unwanted_txn;
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
  } slv_guard_hw2reg_latency_write_reg_t;

  typedef struct packed {
    logic [9:0] d;
    logic        de;
  } slv_guard_hw2reg_latency_read_reg_t;

  // Register -> HW type
  typedef struct packed {
    slv_guard_reg2hw_guard_enable_reg_t guard_enable; // [110:110]
    slv_guard_reg2hw_budget_write_reg_t budget_write; // [109:90]
    slv_guard_reg2hw_budget_read_reg_t budget_read; // [89:70]
    slv_guard_reg2hw_reset_reg_t reset; // [69:69]
    slv_guard_reg2hw_irq_reg_t irq; // [68:52]
    slv_guard_reg2hw_irq_addr_reg_t irq_addr; // [51:20]
    slv_guard_reg2hw_latency_write_reg_t latency_write; // [19:10]
    slv_guard_reg2hw_latency_read_reg_t latency_read; // [9:0]
  } slv_guard_reg2hw_t;

  // HW -> register type
  typedef struct packed {
    slv_guard_hw2reg_guard_enable_reg_t guard_enable; // [123:122]
    slv_guard_hw2reg_budget_write_reg_t budget_write; // [121:101]
    slv_guard_hw2reg_budget_read_reg_t budget_read; // [100:80]
    slv_guard_hw2reg_reset_reg_t reset; // [79:78]
    slv_guard_hw2reg_irq_reg_t irq; // [77:55]
    slv_guard_hw2reg_irq_addr_reg_t irq_addr; // [54:22]
    slv_guard_hw2reg_latency_write_reg_t latency_write; // [21:11]
    slv_guard_hw2reg_latency_read_reg_t latency_read; // [10:0]
  } slv_guard_hw2reg_t;

  // Register offsets
  parameter logic [BlockAw-1:0] SLV_GUARD_GUARD_ENABLE_OFFSET = 5'h 0;
  parameter logic [BlockAw-1:0] SLV_GUARD_BUDGET_WRITE_OFFSET = 5'h 4;
  parameter logic [BlockAw-1:0] SLV_GUARD_BUDGET_READ_OFFSET = 5'h 8;
  parameter logic [BlockAw-1:0] SLV_GUARD_RESET_OFFSET = 5'h c;
  parameter logic [BlockAw-1:0] SLV_GUARD_IRQ_OFFSET = 5'h 10;
  parameter logic [BlockAw-1:0] SLV_GUARD_IRQ_ADDR_OFFSET = 5'h 14;
  parameter logic [BlockAw-1:0] SLV_GUARD_LATENCY_WRITE_OFFSET = 5'h 18;
  parameter logic [BlockAw-1:0] SLV_GUARD_LATENCY_READ_OFFSET = 5'h 1c;

  // Register index
  typedef enum int {
    SLV_GUARD_GUARD_ENABLE,
    SLV_GUARD_BUDGET_WRITE,
    SLV_GUARD_BUDGET_READ,
    SLV_GUARD_RESET,
    SLV_GUARD_IRQ,
    SLV_GUARD_IRQ_ADDR,
    SLV_GUARD_LATENCY_WRITE,
    SLV_GUARD_LATENCY_READ
  } slv_guard_id_e;

  // Register width information to check illegal writes
  parameter logic [3:0] SLV_GUARD_PERMIT [8] = '{
    4'b 0001, // index[0] SLV_GUARD_GUARD_ENABLE
    4'b 0111, // index[1] SLV_GUARD_BUDGET_WRITE
    4'b 0111, // index[2] SLV_GUARD_BUDGET_READ
    4'b 0001, // index[3] SLV_GUARD_RESET
    4'b 0111, // index[4] SLV_GUARD_IRQ
    4'b 1111, // index[5] SLV_GUARD_IRQ_ADDR
    4'b 0011, // index[6] SLV_GUARD_LATENCY_WRITE
    4'b 0011  // index[7] SLV_GUARD_LATENCY_READ
  };

endpackage

