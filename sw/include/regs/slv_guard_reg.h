// Generated register defines for slv_guard

// Copyright information found in source file:
// Copyright 2024 ETH Zurich and University of Bologna.

// Licensing information found in source file:
// Licensed under Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

#ifndef _SLV_GUARD_REG_DEFS_
#define _SLV_GUARD_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define SLV_GUARD_PARAM_REG_WIDTH 32

// Enable slave guard feature
#define SLV_GUARD_GUARD_ENABLE_REG_OFFSET 0x0
#define SLV_GUARD_GUARD_ENABLE_ENABLE_BIT 0

// time budget for one write transaction
#define SLV_GUARD_BUDGET_WRITE_REG_OFFSET 0x4
#define SLV_GUARD_BUDGET_WRITE_BUDGET_WRITE_MASK 0xf
#define SLV_GUARD_BUDGET_WRITE_BUDGET_WRITE_OFFSET 0
#define SLV_GUARD_BUDGET_WRITE_BUDGET_WRITE_FIELD \
  ((bitfield_field32_t) { .mask = SLV_GUARD_BUDGET_WRITE_BUDGET_WRITE_MASK, .index = SLV_GUARD_BUDGET_WRITE_BUDGET_WRITE_OFFSET })

// time budget for one read transaction
#define SLV_GUARD_BUDGET_READ_REG_OFFSET 0x8
#define SLV_GUARD_BUDGET_READ_BUDGET_READ_MASK 0xf
#define SLV_GUARD_BUDGET_READ_BUDGET_READ_OFFSET 0
#define SLV_GUARD_BUDGET_READ_BUDGET_READ_FIELD \
  ((bitfield_field32_t) { .mask = SLV_GUARD_BUDGET_READ_BUDGET_READ_MASK, .index = SLV_GUARD_BUDGET_READ_BUDGET_READ_OFFSET })

// Is the interface requested to be reset?
#define SLV_GUARD_RESET_REG_OFFSET 0xc
#define SLV_GUARD_RESET_RESET_BIT 0

// interrpt cause and clear
#define SLV_GUARD_IRQ_REG_OFFSET 0x10
#define SLV_GUARD_IRQ_WRITE_BIT 0
#define SLV_GUARD_IRQ_READ_BIT 1
#define SLV_GUARD_IRQ_MIS_ID_WR_BIT 2
#define SLV_GUARD_IRQ_MIS_ID_RD_BIT 3
#define SLV_GUARD_IRQ_UNWANTED_TXN_BIT 4
#define SLV_GUARD_IRQ_TXN_ID_MASK 0xfff
#define SLV_GUARD_IRQ_TXN_ID_OFFSET 5
#define SLV_GUARD_IRQ_TXN_ID_FIELD \
  ((bitfield_field32_t) { .mask = SLV_GUARD_IRQ_TXN_ID_MASK, .index = SLV_GUARD_IRQ_TXN_ID_OFFSET })

// address of the transaction going wrong
#define SLV_GUARD_IRQ_ADDR_REG_OFFSET 0x14

// letency of one write txn
#define SLV_GUARD_LATENCY_WRITE_REG_OFFSET 0x18
#define SLV_GUARD_LATENCY_WRITE_LATENCY_WRITE_MASK 0x3ff
#define SLV_GUARD_LATENCY_WRITE_LATENCY_WRITE_OFFSET 0
#define SLV_GUARD_LATENCY_WRITE_LATENCY_WRITE_FIELD \
  ((bitfield_field32_t) { .mask = SLV_GUARD_LATENCY_WRITE_LATENCY_WRITE_MASK, .index = SLV_GUARD_LATENCY_WRITE_LATENCY_WRITE_OFFSET })

// latency of one read txn
#define SLV_GUARD_LATENCY_READ_REG_OFFSET 0x1c
#define SLV_GUARD_LATENCY_READ_LATENCY_AWVLD_WFIRST_MASK 0x3ff
#define SLV_GUARD_LATENCY_READ_LATENCY_AWVLD_WFIRST_OFFSET 0
#define SLV_GUARD_LATENCY_READ_LATENCY_AWVLD_WFIRST_FIELD \
  ((bitfield_field32_t) { .mask = SLV_GUARD_LATENCY_READ_LATENCY_AWVLD_WFIRST_MASK, .index = SLV_GUARD_LATENCY_READ_LATENCY_AWVLD_WFIRST_OFFSET })

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _SLV_GUARD_REG_DEFS_
// End generated register defines for slv_guard