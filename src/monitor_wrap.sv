// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//

`include "axi/assign.svh"
`include "axi/typedef.svh"
`include "register_interface/typedef.svh"

module monitor_wrap 
  import axi_pkg::*;
#(
  // Monitor parameters
  parameter int unsigned MaxUniqIds    = 1,
  parameter int unsigned MaxTxnsPerId  = 2, 
  parameter int unsigned CntWidth      = 10,
  // AXI parameters
  parameter int unsigned AxiAddrWidth  = 64,
  parameter int unsigned AxiDataWidth  = 64,
  parameter int unsigned AxiIdWidth    = 2,
  parameter int unsigned AxiIntIdWidth = (MaxUniqIds > 1) ? $clog2(MaxUniqIds) : 1,
  parameter int unsigned AxiUserWidth  = 1,
  parameter int unsigned AxiLogDepth   = 1,
  // Regbus parameters
  parameter int unsigned  RegAddrWidth = 32,
  parameter int unsigned  RegDataWidth = 32,
  // AXI type dependent parameters; do not override!
  parameter type addr_t   = logic [AxiAddrWidth-1:0],
  parameter type data_t   = logic [AxiDataWidth-1:0],
  parameter type strb_t   = logic [AxiDataWidth/8-1:0],
  parameter type id_t     = logic [AxiIdWidth-1:0],
  parameter type intid_t  = logic [AxiIntIdWidth-1:0],
  parameter type user_t   = logic [AxiUserWidth-1:0],
  //  reg type dependent parameters; do not override!
  parameter type reg_addr_t   = logic [RegAddrWidth-1:0],
  parameter type reg_data_t   = logic [RegDataWidth-1:0],
  parameter type reg_strb_t   = logic [RegDataWidth/8-1:0]
)( 

  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  logic                  guard_ena_i,
  // AXI Master interface
  output id_t                    mst_axi_ar_id_o,
  output addr_t                  mst_axi_ar_addr_o,
  output axi_pkg::len_t          mst_axi_ar_len_o,
  output axi_pkg::size_t         mst_axi_ar_size_o,
  output axi_pkg::burst_t        mst_axi_ar_burst_o,
  output logic                   mst_axi_ar_lock_o,
  output axi_pkg::cache_t        mst_axi_ar_cache_o,
  output axi_pkg::prot_t         mst_axi_ar_prot_o,
  output axi_pkg::qos_t          mst_axi_ar_qos_o,
  output axi_pkg::region_t       mst_axi_ar_region_o,
  output user_t                  mst_axi_ar_user_o,
  output logic                   mst_axi_ar_valid_o,
  input  logic                   mst_axi_ar_ready_i,
  input  id_t                    mst_axi_r_id_i,
  input  data_t                  mst_axi_r_data_i,
  input  axi_pkg::resp_t         mst_axi_r_resp_i,
  input  logic                   mst_axi_r_last_i,
  input  user_t                  mst_axi_r_user_i,
  input  logic                   mst_axi_r_valid_i,
  output logic                   mst_axi_r_ready_o,
  
  output id_t                    mst_axi_aw_id_o,
  output addr_t                  mst_axi_aw_addr_o,
  output axi_pkg::len_t          mst_axi_aw_len_o,
  output axi_pkg::size_t         mst_axi_aw_size_o,
  output axi_pkg::burst_t        mst_axi_aw_burst_o,
  output logic                   mst_axi_aw_lock_o,
  output axi_pkg::cache_t        mst_axi_aw_cache_o,
  output axi_pkg::prot_t         mst_axi_aw_prot_o,
  output axi_pkg::qos_t          mst_axi_aw_qos_o,
  output axi_pkg::region_t       mst_axi_aw_region_o,
  output axi_pkg::atop_t         mst_axi_aw_atop_o,
  output user_t                  mst_axi_aw_user_o,
  output logic                   mst_axi_aw_valid_o,
  input  logic                   mst_axi_aw_ready_i,
  output data_t                  mst_axi_w_data_o,
  output strb_t                  mst_axi_w_strb_o,
  output logic                   mst_axi_w_last_o,
  output user_t                  mst_axi_w_user_o,
  output logic                   mst_axi_w_valid_o,
  input  logic                   mst_axi_w_ready_i,
  input  id_t                    mst_axi_b_id_i,
  input  axi_pkg::resp_t         mst_axi_b_resp_i,
  input  user_t                  mst_axi_b_user_i,
  input  logic                   mst_axi_b_valid_i,
  output logic                   mst_axi_b_ready_o, 
  // AXI Slave port
  output id_t                    slv_axi_ar_id_o,
  output addr_t                  slv_axi_ar_addr_o,
  output axi_pkg::len_t          slv_axi_ar_len_o,
  output axi_pkg::size_t         slv_axi_ar_size_o,
  output axi_pkg::burst_t        slv_axi_ar_burst_o,
  output logic                   slv_axi_ar_lock_o,
  output axi_pkg::cache_t        slv_axi_ar_cache_o,
  output axi_pkg::prot_t         slv_axi_ar_prot_o,
  output axi_pkg::qos_t          slv_axi_ar_qos_o,
  output axi_pkg::region_t       slv_axi_ar_region_o,
  output user_t                  slv_axi_ar_user_o,
  output logic                   slv_axi_ar_valid_o,
  input  logic                   slv_axi_ar_ready_i,
  input  id_t                    slv_axi_r_id_i,
  input  data_t                  slv_axi_r_data_i,
  input  axi_pkg::resp_t         slv_axi_r_resp_i,
  input  logic                   slv_axi_r_last_i,
  input  user_t                  slv_axi_r_user_i,
  input  logic                   slv_axi_r_valid_i,
  output logic                   slv_axi_r_ready_o,
  
  output id_t                    slv_axi_aw_id_o,
  output addr_t                  slv_axi_aw_addr_o,
  output axi_pkg::len_t          slv_axi_aw_len_o,
  output axi_pkg::size_t         slv_axi_aw_size_o,
  output axi_pkg::burst_t        slv_axi_aw_burst_o,
  output logic                   slv_axi_aw_lock_o,
  output axi_pkg::cache_t        slv_axi_aw_cache_o,
  output axi_pkg::prot_t         slv_axi_aw_prot_o,
  output axi_pkg::qos_t          slv_axi_aw_qos_o,
  output axi_pkg::region_t       slv_axi_aw_region_o,
  output axi_pkg::atop_t         slv_axi_aw_atop_o,
  output user_t                  slv_axi_aw_user_o,
  output logic                   slv_axi_aw_valid_o,
  input  logic                   slv_axi_aw_ready_i,
  output data_t                  slv_axi_w_data_o,
  output strb_t                  slv_axi_w_strb_o,
  output logic                   slv_axi_w_last_o,
  output user_t                  slv_axi_w_user_o,
  output logic                   slv_axi_w_valid_o,
  input  logic                   slv_axi_w_ready_i,
  input  id_t                    slv_axi_b_id_i,
  input  axi_pkg::resp_t         slv_axi_b_resp_i,
  input  user_t                  slv_axi_b_user_i,
  input  logic                   slv_axi_b_valid_i,
  output logic                   slv_axi_b_ready_o, 
  // Reg bus
  input reg_addr_t               reg_req_addr_i,
  input logic                    reg_req_write_i,
  input reg_data_t               reg_req_wdata_i,
  input reg_strb_t               reg_req_strb_i,
  input logic                    reg_req_valid_i,
  
  output reg_data_t              reg_rsp_rdata_o,
  output logic                   reg_rsp_error_o,
  output logic                   reg_rsp_ready_o,
  output logic                   irq_o,
  output logic                   rst_req_o
);  

   // AXI4+ATOP master typedefs
  `AXI_TYPEDEF_AW_CHAN_T(axi_aw_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(axi_w_chan_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(axi_b_chan_t, id_t, user_t)

  `AXI_TYPEDEF_AR_CHAN_T(axi_ar_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(axi_r_chan_t, data_t, id_t, user_t)

  `AXI_TYPEDEF_REQ_T(mst_req_t, axi_aw_chan_t, axi_w_chan_t, axi_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(mst_rsp_t, axi_b_chan_t, axi_r_chan_t)
   
    // AXI4+ATOP slave typedefs
  `AXI_TYPEDEF_AW_CHAN_T(slv_aw_chan_t, addr_t, intid_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(slv_w_chan_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(slv_b_chan_t, intid_t, user_t)

  `AXI_TYPEDEF_AR_CHAN_T(slv_ar_chan_t, addr_t, intid_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(slv_r_chan_t, data_t, intid_t, user_t)

  `AXI_TYPEDEF_REQ_T(slv_req_t, slv_aw_chan_t, slv_w_chan_t, slv_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(slv_rsp_t, slv_b_chan_t, slv_r_chan_t)
  
  // regbus typedefs
  `REG_BUS_TYPEDEF_ALL(cfg, reg_addr_t, reg_data_t, reg_strb_t) 
  
  mst_req_t mst_req;
  mst_rsp_t mst_rsp;

  slv_req_t slv_req;
  slv_rsp_t slv_rsp;

  cfg_req_t cfg_req;
  cfg_rsp_t cfg_rsp;

  // AXI4+ATOP Read Master
  assign mst_axi_ar_id_o     = mst_req.ar.id;
  assign mst_axi_ar_addr_o   = mst_req.ar.addr;
  assign mst_axi_ar_len_o    = mst_req.ar.len;
  assign mst_axi_ar_size_o   = mst_req.ar.size;
  assign mst_axi_ar_burst_o  = mst_req.ar.burst;
  assign mst_axi_ar_lock_o   = mst_req.ar.lock;
  assign mst_axi_ar_cache_o  = mst_req.ar.cache;
  assign mst_axi_ar_prot_o   = mst_req.ar.prot;
  assign mst_axi_ar_qos_o    = mst_req.ar.qos;
  assign mst_axi_ar_region_o = mst_req.ar.region;
  assign mst_axi_ar_user_o   = mst_req.ar.user;
  assign mst_axi_ar_valid_o  = mst_req.ar_valid;
  assign mst_axi_r_ready_o   = mst_req.r_ready;
  
  assign mst_rsp.ar_ready = mst_axi_ar_ready_i;
  assign mst_rsp.r.id     = mst_axi_r_id_i;
  assign mst_rsp.r.data   = mst_axi_r_data_i;
  assign mst_rsp.r.resp   = mst_axi_r_resp_i;
  assign mst_rsp.r.last   = mst_axi_r_last_i;
  assign mst_rsp.r.user   = mst_axi_r_user_i;
  assign mst_rsp.r_valid  = mst_axi_r_valid_i;

  // AXI4+ATOP Write Master
  assign mst_axi_aw_id_o     = mst_req.aw.id;
  assign mst_axi_aw_addr_o   = mst_req.aw.addr;
  assign mst_axi_aw_len_o    = mst_req.aw.len;
  assign mst_axi_aw_size_o   = mst_req.aw.size;
  assign mst_axi_aw_burst_o  = mst_req.aw.burst;
  assign mst_axi_aw_lock_o   = mst_req.aw.lock;
  assign mst_axi_aw_cache_o  = mst_req.aw.cache;
  assign mst_axi_aw_prot_o   = mst_req.aw.prot;
  assign mst_axi_aw_qos_o    = mst_req.aw.qos;
  assign mst_axi_aw_region_o = mst_req.aw.region;
  assign mst_axi_aw_atop_o   = mst_req.aw.atop;
  assign mst_axi_aw_user_o   = mst_req.aw.user;
  assign mst_axi_aw_valid_o  = mst_req.aw_valid;
  assign mst_axi_w_data_o    = mst_req.w.data;
  assign mst_axi_w_strb_o    = mst_req.w.strb;
  assign mst_axi_w_last_o    = mst_req.w.last;
  assign mst_axi_w_user_o    = mst_req.w.user;
  assign mst_axi_w_valid_o   = mst_req.w_valid;
  assign mst_axi_b_ready_o   = mst_req.b_ready;
  
  assign mst_rsp.aw_ready = mst_axi_aw_ready_i;
  assign mst_rsp.w_ready  = mst_axi_w_ready_i;
  assign mst_rsp.b.id     = mst_axi_b_id_i;
  assign mst_rsp.b.resp   = mst_axi_b_resp_i;
  assign mst_rsp.b.user   = mst_axi_b_user_i;
  assign mst_rsp.b_valid  = mst_axi_b_valid_i;

  // AXI4+ATOP Read Slave
  assign slv_axi_ar_id_o     = slv_req.ar.id;
  assign slv_axi_ar_addr_o   = slv_req.ar.addr;
  assign slv_axi_ar_len_o    = slv_req.ar.len;
  assign slv_axi_ar_size_o   = slv_req.ar.size;
  assign slv_axi_ar_burst_o  = slv_req.ar.burst;
  assign slv_axi_ar_lock_o   = slv_req.ar.lock;
  assign slv_axi_ar_cache_o  = slv_req.ar.cache;
  assign slv_axi_ar_prot_o   = slv_req.ar.prot;
  assign slv_axi_ar_qos_o    = slv_req.ar.qos;
  assign slv_axi_ar_region_o = slv_req.ar.region;
  assign slv_axi_ar_user_o   = slv_req.ar.user;
  assign slv_axi_ar_valid_o  = slv_req.ar_valid;
  assign slv_axi_r_ready_o   = slv_req.r_ready;
  
  assign slv_rsp.ar_ready = slv_axi_ar_ready_i;
  assign slv_rsp.r.id     = slv_axi_r_id_i;
  assign slv_rsp.r.data   = slv_axi_r_data_i;
  assign slv_rsp.r.resp   = slv_axi_r_resp_i;
  assign slv_rsp.r.last   = slv_axi_r_last_i;
  assign slv_rsp.r.user   = slv_axi_r_user_i;
  assign slv_rsp.r_valid  = slv_axi_r_valid_i;

  // AXI4+ATOP Slave
  assign slv_axi_aw_id_o     = slv_req.aw.id;
  assign slv_axi_aw_addr_o   = slv_req.aw.addr;
  assign slv_axi_aw_len_o    = slv_req.aw.len;
  assign slv_axi_aw_size_o   = slv_req.aw.size;
  assign slv_axi_aw_burst_o  = slv_req.aw.burst;
  assign slv_axi_aw_lock_o   = slv_req.aw.lock;
  assign slv_axi_aw_cache_o  = slv_req.aw.cache;
  assign slv_axi_aw_prot_o   = slv_req.aw.prot;
  assign slv_axi_aw_qos_o    = slv_req.aw.qos;
  assign slv_axi_aw_region_o = slv_req.aw.region;
  assign slv_axi_aw_atop_o   = slv_req.aw.atop;
  assign slv_axi_aw_user_o   = slv_req.aw.user;
  assign slv_axi_aw_valid_o  = slv_req.aw_valid;
  assign slv_axi_w_data_o    = slv_req.w.data;
  assign slv_axi_w_strb_o    = slv_req.w.strb;
  assign slv_axi_w_last_o    = slv_req.w.last;
  assign slv_axi_w_user_o    = slv_req.w.user;
  assign slv_axi_w_valid_o   = slv_req.w_valid;
  assign slv_axi_b_ready_o   = slv_req.b_ready;
  
  assign slv_rsp.aw_ready = slv_axi_aw_ready_i;
  assign slv_rsp.w_ready  = slv_axi_w_ready_i;
  assign slv_rsp.b.id     = slv_axi_b_id_i;
  assign slv_rsp.b.resp   = slv_axi_b_resp_i;
  assign slv_rsp.b.user   = slv_axi_b_user_i;
  assign slv_rsp.b_valid  = slv_axi_b_valid_i;

  // Reg
  assign cfg_req.addr    =  reg_req_addr_i;
  assign cfg_req.write   =  reg_req_write_i;
  assign cfg_req.wdata   =  reg_req_wdata_i;
  assign cfg_req.wstrb   =  reg_req_strb_i;
  assign cfg_req.valid   =  reg_req_valid_i;
  
  assign reg_rsp_rdata_o =  cfg_rsp.rdata;
  assign reg_rsp_error_o =  cfg_rsp.error;
  assign reg_rsp_ready_o =  cfg_rsp.ready;

  slv_guard_top #(
    .AddrWidth    ( AxiAddrWidth   ),
    .DataWidth    ( AxiDataWidth   ),
    .StrbWidth    ( AxiDataWidth/8 ),
    .AxiIdWidth   ( AxiIdWidth     ),
    .AxiUserWidth ( AxiUserWidth   ),
    .MaxTxnsPerId ( MaxTxnsPerId   ),
    .MaxUniqIds   ( MaxUniqIds     ),
    .CntWidth     ( CntWidth       ),
    .IntIdWidth   ( AxiIntIdWidth  ),
    .req_t        ( mst_req_t      ), 
    .rsp_t        ( mst_rsp_t      ),
    .int_req_t    ( slv_req_t      ),
    .int_rsp_t    ( slv_rsp_t      ),
    .reg_req_t    ( cfg_req_t      ), 
    .reg_rsp_t    ( cfg_rsp_t      )
  ) i_slv_guard (
    .clk_i       (   clk_i        ),
    .rst_ni      (   rst_ni       ),
    .guard_ena_i (   1'b1         ),
    .req_i       (   mst_req      ), 
    .rsp_o       (   mst_rsp      ),
    .req_o       (   slv_req      ),
    .rsp_i       (   slv_rsp      ),
    .reg_req_i   (   cfg_req      ),
    .reg_rsp_o   (   cfg_rsp      ),
    .irq_o       (                ),
    .rst_req_o   (                ),
    .rst_stat_i (                 )
  );
endmodule: monitor_wrap