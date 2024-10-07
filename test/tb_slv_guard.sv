
// `include "assign.svh"
// `include "axi_typedef.svh"
// `include "typedef.svh"

`include "axi/assign.svh"
`include "axi/typedef.svh"
`include "register_interface/typedef.svh"

import slv_pkg::*;

/// Testbench for the slave monitring unit 
module tb_slv_guard #(
  /// Testbench timing
  parameter time CyclTime                = 10000ps,
  parameter time ApplTime                = 100ps,
  parameter time TestTime                = 500ps
);
  
  slv_pkg::cfg_req_t cfg_req;
  slv_pkg::cfg_rsp_t cfg_rsp;

  typedef reg_test::reg_driver #(
    .AW ( slv_pkg::AxiAddrWidth ),
    .DW ( 32             ),
    .TA ( ApplTime       ),
    .TT ( TestTime       )
  ) reg_drv_t;

  typedef axi_test::axi_file_master#(
    .AW                   ( slv_pkg::AxiAddrWidth ),
    .DW                   ( slv_pkg::AxiDataWidth ),
    .IW                   ( slv_pkg::AxiIdWidth   ),
    .UW                   ( slv_pkg::AxiUserWidth ),
    .TA                   ( ApplTime       ),
    .TT                   ( TestTime       )
  ) axi_file_master_t;

  typedef axi_test::axi_driver #(
    .AW( slv_pkg::AxiAddrWidth ),
    .DW( slv_pkg::AxiDataWidth ),
    .IW( slv_pkg::AxiIdWidth   ),
    .UW( slv_pkg::AxiUserWidth ),
    .TA( ApplTime       ),
    .TT( TestTime       )
  ) axi_drv_t;

  // -------------
  // DUT signals
  // -------------
  logic clk;
  logic rst_n;
  logic         reg_error;
  logic [31:0]  reg_data;
  logic guard_configured;
  logic irq, rst_stat;

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( slv_pkg::AxiAddrWidth ),
    .AXI_DATA_WIDTH ( slv_pkg::AxiDataWidth ),
    .AXI_ID_WIDTH   ( slv_pkg::AxiIdWidth   ),
    .AXI_USER_WIDTH ( slv_pkg::AxiUserWidth )
  ) master();

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( slv_pkg::AxiAddrWidth ),
    .AXI_DATA_WIDTH ( slv_pkg::AxiDataWidth ),
    .AXI_ID_WIDTH   ( slv_pkg::AxiIdWidth   ),
    .AXI_USER_WIDTH ( slv_pkg::AxiUserWidth )
  ) slave();

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( slv_pkg::AxiAddrWidth ),
    .AXI_DATA_WIDTH ( slv_pkg::AxiDataWidth ),
    .AXI_ID_WIDTH   ( slv_pkg::AxiIdWidth   ),
    .AXI_USER_WIDTH ( slv_pkg::AxiUserWidth )
  ) master_dv(clk);

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( slv_pkg::AxiAddrWidth ),
    .AXI_DATA_WIDTH ( slv_pkg::AxiDataWidth ),
    .AXI_ID_WIDTH   ( slv_pkg::AxiIdWidth   ),
    .AXI_USER_WIDTH ( slv_pkg::AxiUserWidth )
  ) slave_dv(clk);

  slv_pkg::mst_req_t   master_req;
  slv_pkg::mst_resp_t   master_rsp;

  slv_pkg::slv_req_t   slave_req;
  slv_pkg::slv_resp_t   slave_rsp;

  `AXI_ASSIGN (master,           master_dv)
  `AXI_ASSIGN_TO_REQ(master_req, master)
  `AXI_ASSIGN_FROM_RESP(master,  master_rsp)
  
  `AXI_ASSIGN (slave_dv,         slave)
  `AXI_ASSIGN_FROM_REQ(slave,    slave_req)
  `AXI_ASSIGN_TO_RESP(slave_rsp, slave)

  REG_BUS #(
    .ADDR_WIDTH ( slv_pkg::AxiAddrWidth ),
    .DATA_WIDTH ( slv_pkg::AxiDataWidth )
  ) reg_bus (clk);

  assign cfg_req.addr  = reg_bus.addr;
  assign cfg_req.wdata = reg_bus.wdata;
  assign cfg_req.wstrb = reg_bus.wstrb;
  assign cfg_req.write = reg_bus.write;
  assign cfg_req.valid = reg_bus.valid;
  assign reg_bus.rdata = cfg_rsp.rdata;
  assign reg_bus.error = cfg_rsp.error;
  assign reg_bus.ready = cfg_rsp.ready;

  //-----------------------------------
  // Clock generator
  //-----------------------------------
  clk_rst_gen #(
      .ClkPeriod    ( CyclTime ),
      .RstClkCycles ( 32'd5    )
  ) i_clk_gen (
      .clk_o        ( clk      ),
      .rst_no       ( rst_n    )
  );

  //-----------------------------------
  // AXI Simulation Memory 
  //-----------------------------------
   axi_sim_mem #(
    .AddrWidth         ( slv_pkg::AxiAddrWidth  ),
    .DataWidth         ( slv_pkg::AxiDataWidth  ),
    .IdWidth           ( slv_pkg::AxiIdWidth    ),
    .UserWidth         ( slv_pkg::AxiUserWidth  ),
    .axi_req_t         ( slv_pkg::slv_req_t     ),
    .axi_rsp_t         ( slv_pkg::slv_resp_t    ),
    .WarnUninitialized ( 1'b0            ),
    .ClearErrOnAccess  ( 1'b1            ),
    .ApplDelay         ( ApplTime        ),
    .AcqDelay          ( TestTime        )  
  ) i_tx_axi_sim_mem (
    .clk_i              ( clk           ),
    .rst_ni             ( rst_n         ),
    .axi_req_i          ( slave_req     ),  
    .axi_rsp_o          ( slave_rsp     ),
    .mon_r_last_o       ( /* NOT CONNECTED */ ),
    .mon_r_beat_count_o ( /* NOT CONNECTED */ ),
    .mon_r_user_o       ( /* NOT CONNECTED */ ),
    .mon_r_id_o         ( /* NOT CONNECTED */ ),
    .mon_r_data_o       ( /* NOT CONNECTED */ ),
    .mon_r_addr_o       ( /* NOT CONNECTED */ ),
    .mon_r_valid_o      ( /* NOT CONNECTED */ ),
    .mon_w_last_o       ( /* NOT CONNECTED */ ),
    .mon_w_beat_count_o ( /* NOT CONNECTED */ ),
    .mon_w_user_o       ( /* NOT CONNECTED */ ),
    .mon_w_id_o         ( /* NOT CONNECTED */ ),
    .mon_w_data_o       ( /* NOT CONNECTED */ ),
    .mon_w_addr_o       ( /* NOT CONNECTED */ ),
    .mon_w_valid_o      ( /* NOT CONNECTED */ )
  );

  //-----------------------------------
  // DUT
  //-----------------------------------
  slv_guard_top
  // `ifndef TARGET_NETLIST_SIM
   #(
    .AddrWidth    ( slv_pkg::AxiAddrWidth ),
    .DataWidth    ( slv_pkg::AxiDataWidth ),
    .StrbWidth    ( slv_pkg::AxiDataWidth/8  ),
    .AxiIdWidth   ( slv_pkg::AxiIdWidth   ),
    .AxiUserWidth ( slv_pkg::AxiUserWidth ),
    .MaxTxnsPerId ( slv_pkg::MaxTxnsPerId ),
    .MaxUniqIds   ( slv_pkg::MaxUniqIds   ),
    .CntWidth     ( slv_pkg::CntWidth     ),
    .PrescalerDiv ( slv_pkg::PrescalerDiv ),
    .req_t        ( slv_pkg::mst_req_t    ), 
    .rsp_t        ( slv_pkg::mst_resp_t   ),
    .slv_req_t    ( slv_pkg::slv_req_t    ),
    .slv_rsp_t    ( slv_pkg::slv_resp_t   ),
    .reg_req_t    ( slv_pkg::cfg_req_t    ), 
    .reg_rsp_t    ( slv_pkg::cfg_rsp_t    )
  )
  //`endif
  //monitor_wrap
    i_slv_guard_top (
    .clk_i       (   clk          ),
    .rst_ni      (   rst_n        ),
    .guard_ena_i (   1'b1         ), // can also do sw write
    .req_i       (   master_req   ), 
    .rsp_o       (   master_rsp   ),
    .req_o       (   slave_req    ),
    .rsp_i       (   slave_rsp    ),
    .reg_req_i   (   cfg_req      ),
    .reg_rsp_o   (   cfg_rsp      ),
    .irq_o       (   irq          ),
    .rst_req_o   (   rst_stat     ),
    .rst_stat_i  (   1'b1         )
  );

//-----------------------------------
// TB
//-----------------------------------

  initial begin : proc_axi_master
    automatic axi_file_master_t axi_file_master = new(master_dv);
    axi_file_master.reset();
    axi_file_master.load_files($sformatf("/scratch/chaol/slave_unit/single-with/single-counter/single-sim/slv_guard/test/stimuli/axi_rt_reads.txt"), $sformatf("/scratch/chaol/slave_unit/single-with/single-counter/single-sim/slv_guard/test/stimuli/32_wr.txt"));
    // tb metrics
    // total_num_reads [i] = axi_file_master.num_reads;
    // total_num_writes[i] = axi_file_master.num_writes;
    // num_writes      [i] = 1;
    // num_reads       [i] = 1;
    // end_of_sim [i] = 1'b0;

    // wait for config
    @(posedge rst_n);
    @(posedge clk);

    repeat (5) @(posedge clk);
    // run
    axi_file_master.run();

  end
 
  // configure slv units
  initial begin
    // register bus
    automatic reg_drv_t reg_drv = new(reg_bus);
    guard_configured = 0;
    reg_drv.reset_master();
    @(posedge rst_n);
    @(posedge clk);

    // slave unit enable 1 / disable 0
    reg_drv.send_write(32'h0000_0000, 32'h0000_0001, 4'h1, reg_error);

    // write_budget
    reg_drv.send_write(32'h0000_0004, 32'h0000_0001, 'hff, reg_error); 

    // read_budget
    reg_drv.send_write(32'h0000_0008, 32'h0000_0001, 4'hf, reg_error);

    repeat (5) @(posedge clk);

    // config is done
    guard_configured = 1;
    //$stop();
  end

endmodule