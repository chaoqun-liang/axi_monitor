/// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
`include "axi/assign.svh"
`include "axi/typedef.svh"
`include "register_interface/typedef.svh"

package slv_pkg;

// Monitor parameters
  parameter int unsigned MaxUniqIds    = 32;
  parameter int unsigned MaxTxnsPerId  = 1; 
  parameter int unsigned MaxTxns       = MaxUniqIds * MaxTxnsPerId;
  parameter int unsigned CntWidth      = 10;
  parameter int unsigned HsCntWidth    = 8;
  parameter int unsigned AccuCntWidth = CntWidth+1;
  // AXI parameters
  parameter int unsigned AxiAddrWidth  = 48;
  parameter int unsigned AxiDataWidth  = 32;
  parameter int unsigned AxiIdWidth    = 6; 
  parameter int unsigned AxiIntIdWidth = (MaxUniqIds > 1) ? $clog2(MaxUniqIds) : 1;
  parameter int unsigned AxiUserWidth  = 1;
  parameter int unsigned AxiLogDepth   = 1;
  // Regbus parameters
  parameter int unsigned  RegAddrWidth = 32;
  parameter int unsigned  RegDataWidth = 32;
  
  // AXI type dependent parameters; do not override!
  parameter type addr_t   = logic [AxiAddrWidth-1:0];
  parameter type data_t   = logic [AxiDataWidth-1:0];
  parameter type strb_t   = logic [AxiDataWidth/8-1:0];
  parameter type id_t     = logic [AxiIdWidth-1:0];
  parameter type intid_t  = logic [AxiIntIdWidth-1:0];
  parameter type user_t   = logic [AxiUserWidth-1:0];

  //  reg type dependent parameters; do not override!
  parameter type reg_addr_t   = logic [RegAddrWidth-1:0];
  parameter type reg_data_t   = logic [RegDataWidth-1:0];
  parameter type reg_strb_t   = logic [RegDataWidth/8-1:0];

  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t);
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(r_chan_t, data_t, id_t, user_t);
  `AXI_TYPEDEF_REQ_T(mst_req_t, aw_chan_t, w_chan_t, ar_chan_t);
  `AXI_TYPEDEF_RESP_T(mst_resp_t, b_chan_t, r_chan_t );
  
  /// Intermediate AXI types
  `AXI_TYPEDEF_AW_CHAN_T(int_aw_t, addr_t, intid_t, user_t);
  `AXI_TYPEDEF_W_CHAN_T(w_t, data_t, strb_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(int_b_t, intid_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(int_ar_t, addr_t, intid_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(int_r_t, data_t, intid_t, user_t);
  `AXI_TYPEDEF_REQ_T(slv_req_t, int_aw_t, w_t, int_ar_t);
  `AXI_TYPEDEF_RESP_T(slv_resp_t, int_b_t, int_r_t );

  `REG_BUS_TYPEDEF_ALL(cfg, reg_addr_t, reg_data_t, reg_strb_t);
  
  localparam int unsigned LdIdxWidth = cf_math_pkg::idx_width(MaxTxns);
  
  typedef logic [AxiIntIdWidth-1:0] int_id_t;
  typedef logic [AccuCntWidth-1:0] accu_cnt_t;
  typedef logic [CntWidth-1:0] cnt_t;
  typedef logic [HsCntWidth-1:0] hs_cnt_t;
  typedef logic [LdIdxWidth-1:0] ld_idx_t;
  // Transaction counter type def
  typedef struct packed {
    // AWVALID to AWREADY
    hs_cnt_t cnt_awvalid_awready; 
    // AWVALID to WFIRST
    accu_cnt_t cnt_awvalid_wfirst; 
    // WVALID to WREADY of WFIRST 
    hs_cnt_t cnt_wvalid_wready_first; 
    // WFIRST to WLAST
    cnt_t    cnt_wfirst_wlast;  
    // WLAST to BVALID  
    hs_cnt_t cnt_wlast_bvalid;  
    // WLAST to BREADY  
    hs_cnt_t cnt_bvalid_bready;   
  } write_cnters_t;
  
  // FSM per each transaction
  typedef enum logic [1:0] {
    WRITE_IDLE,// for idle LD entries retired from aw-w-b lifecycle
    WRITE_ADDRESS,
    WRITE_DATA,
    WRITE_RESPONSE
  } write_state_t;
  
  typedef struct packed {                      
    int_id_t        id;                             
    axi_pkg::len_t  len; // 8 bits
  } meta_t;

  // LD entry for each txn
  typedef struct packed {
    // Txn meta info, put AW channel info  
    meta_t          metadata;
    // AW, W, B or IDLE(after dequeue)
    write_state_t   write_state;
    // Six counters per each write txn
    write_cnters_t  counters; 
    // W1 and w3 are dynamic budget determined by unit_budget given in sw and accum length in hw
    // AW_VALID to W_VALID (W_FIRST)
    accu_cnt_t      w1_budget; 
    // W_VALID to W_LAST (W_FIRST to W_LAST)
    cnt_t           w3_budget;
    // Next pointer in LD table
    ld_idx_t        next;
    // Is this LD entry occupied by any txn?
    logic           free;
  } linked_wr_data_t;
  
  // Transaction counter type def
  typedef struct packed {
    // ARVALID to ARREADY
    hs_cnt_t cnt_arvalid_arready; 
    // ARVALID to RVALID
    accu_cnt_t cnt_arvalid_rfirst;  
    // RVALID to RREADY
    hs_cnt_t cnt_rvalid_rready_first; 
    // RVALID to RLAST
    cnt_t cnt_rfirst_rlast;   
  } read_cnters_t;

  // FSM state of each transaction
  typedef enum logic [1:0] {
    READ_IDLE,
    READ_ADDRESS,
    READ_DATA,
    READ_RESPONSE
  } read_state_t;

  // Type of an entry in the linked data table.
  typedef struct packed {
    meta_t          metadata;
    read_state_t    read_state;
    read_cnters_t   counters;
    // txn-specific dynamic budget
    accu_cnt_t      r1_budget;
    cnt_t           r3_budget;
    ld_idx_t        next;
    logic           free;
  } linked_rd_data_t;
endpackage