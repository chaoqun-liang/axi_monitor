
`include "axi/assign.svh"
`include "axi/typedef.svh"
`include "register_interface/typedef.svh"

/// Testbench for the slave monitring unit
module tb_slv_guard #(
  /// Testbench timing
  parameter time CyclTime                = 10000ps,
  parameter time ApplTime                = 100ps,
  parameter time TestTime                = 500ps,
  /// AXI configuration
  parameter int unsigned TbAxiIdWidth    = 32'd2,
  parameter int unsigned TbAxiAddrWidth  = 32'd32,
  parameter int unsigned TbAxiDataWidth  = 32'd32,
  parameter int unsigned TbAxiUserWidth  = 32'd1 
);
  
  /// Sim print config, how many transactions
  localparam int unsigned TbPrintTnx = 32'd100;

  /// Slave Monitoring unit parameters
  localparam int unsigned MaxTxnsPerId = 32'd4; 
  localparam int unsigned MaxWrUniqIds = 32'd4;
  localparam int unsigned MaxRdUniqIds = 32'd4;
  localparam int unsigned MaxWrTxns = 32'd8;
  localparam int unsigned MaxRdTxns = 32'd4;
  localparam int unsigned CntWidth  = 32;
  localparam int unsigned IntIdWidth = 2;

  localparam int unsigned AxiStrbWidth = TbAxiDataWidth/8;

  /// AXI4+ATOP typedefs
  typedef logic [TbAxiIdWidth-1    :0] id_t;
  typedef logic [TbAxiAddrWidth-1  :0] addr_t;
  typedef logic [TbAxiDataWidth-1  :0] data_t;
  typedef logic [AxiStrbWidth-1    :0] strb_t;
  typedef logic [TbAxiUserWidth-1  :0] user_t;

  typedef logic [IntIdWidth-1:0] int_id_t;
 

  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t);
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(r_chan_t, data_t, id_t, user_t);
  `AXI_TYPEDEF_REQ_T(axi_req_t, aw_chan_t, w_chan_t, ar_chan_t);
  `AXI_TYPEDEF_RESP_T(axi_rsp_t, b_chan_t, r_chan_t );
  
  /// Intermediate AXI types
  `AXI_TYPEDEF_AW_CHAN_T(int_aw_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_W_CHAN_T(w_t, data_t, strb_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(int_b_t, int_id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(int_ar_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(int_r_t, data_t, int_id_t, user_t);
  `AXI_TYPEDEF_REQ_T(slv_req_t, int_aw_t, w_t, int_ar_t);
  `AXI_TYPEDEF_RESP_T(slv_rsp_t, int_b_t, int_r_t );

  `REG_BUS_TYPEDEF_ALL(cfg, addr_t, logic[31:0], logic[3:0]) 

  cfg_req_t cfg_req;
  cfg_rsp_t cfg_rsp;


  typedef reg_test::reg_driver #(
    .AW ( TbAxiAddrWidth ),
    .DW ( 32             ),
    .TA ( ApplTime       ),
    .TT ( TestTime       )
  ) reg_drv_t;

    typedef axi_test::axi_file_master#(
      .AW                   ( TbAxiAddrWidth ),
      .DW                   ( TbAxiDataWidth ),
      .IW                   ( TbAxiIdWidth   ),
      .UW                   ( TbAxiUserWidth ),
      .TA                   ( ApplTime       ),
      .TT                   ( TestTime       )
  ) axi_file_master_t;

  typedef axi_test::axi_driver #(
    .AW( TbAxiAddrWidth ),
    .DW( TbAxiDataWidth ),
    .IW( TbAxiIdWidth   ),
    .UW( TbAxiUserWidth ),
    .TA( ApplTime       ),
    .TT( TestTime       )
  ) axi_drv_t;

  // -------------
  // DUT signals
  // -------------
  logic clk;
  logic rst_n;
  logic                     reg_error;
  logic [31:0]              reg_data;
  logic guard_configured;

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth ),
    .AXI_ID_WIDTH   ( TbAxiIdWidth   ),
    .AXI_USER_WIDTH ( TbAxiUserWidth )
  ) master();

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth  ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth  ),
    .AXI_ID_WIDTH   ( TbAxiIdWidth    ),
    .AXI_USER_WIDTH ( TbAxiUserWidth  )
  ) slave();

  AXI_BUS_DV #(
      .AXI_ADDR_WIDTH ( TbAxiAddrWidth ),
      .AXI_DATA_WIDTH ( TbAxiDataWidth ),
      .AXI_ID_WIDTH   ( TbAxiIdWidth   ),
      .AXI_USER_WIDTH ( TbAxiUserWidth )
  ) master_dv(clk);

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth  ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth  ),
    .AXI_ID_WIDTH   ( TbAxiIdWidth    ),
    .AXI_USER_WIDTH ( TbAxiUserWidth  )
  ) slave_dv(clk);

  axi_req_t   master_req;
  axi_rsp_t   master_rsp;

  axi_req_t   slave_req;
  axi_rsp_t   slave_rsp;

  `AXI_ASSIGN (master,           master_dv)
  `AXI_ASSIGN_TO_REQ(master_req, master)
  `AXI_ASSIGN_FROM_RESP(master,  master_rsp)
  
  `AXI_ASSIGN (slave_dv,         slave)
  `AXI_ASSIGN_FROM_REQ(slave,    slave_req)
  `AXI_ASSIGN_TO_RESP(slave_rsp, slave)

  REG_BUS #(
    .ADDR_WIDTH ( TbAxiAddrWidth ),
    .DATA_WIDTH ( TbAxiDataWidth )
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
    .AddrWidth         ( TbAxiAddrWidth    ),
    .DataWidth         ( TbAxiDataWidth    ),
    .IdWidth           ( TbAxiIdWidth        ),
    .UserWidth         ( TbAxiUserWidth    ),
    .axi_req_t         ( axi_req_t    ),
    .axi_rsp_t         ( axi_rsp_t    ),
    .WarnUninitialized ( 1'b0         ),
    .ClearErrOnAccess  ( 1'b1         ),
    .ApplDelay         ( ApplTime       ),
    .AcqDelay          ( TestTime       )  
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
  slv_guard_top #(
    .AddrWidth    ( TbAxiAddrWidth ),
    .DataWidth    ( TbAxiDataWidth ),
    .StrbWidth    ( AxiStrbWidth   ),
    .AxiIdWidth   ( TbAxiIdWidth   ),
    .AxiUserWidth ( TbAxiUserWidth ),
    .MaxTxnsPerId ( MaxTxnsPerId   ),
    .MaxWrUniqIds ( MaxWrUniqIds   ),
    .MaxRdUniqIds ( MaxRdUniqIds   ),
    .MaxWrTxns    ( MaxWrTxns      ),
    .MaxRdTxns    ( MaxRdTxns      ),
    .CntWidth     ( CntWidth       ),
    .IntIdWidth   ( IntIdWidth     ),
    .req_t        ( axi_req_t      ), 
    .rsp_t        ( axi_rsp_t      ),
    .slv_req_t    ( slv_req_t      ),
    .slv_rsp_t    ( slv_rsp_t      ),
    .reg_req_t    ( cfg_req_t      ), 
    .reg_rsp_t    ( cfg_rsp_t      )
) i_slv_guard (
    .clk_i       (   clk          ),
    .rst_ni      (   rst_n        ),
    .guard_ena_i (   1'b1            ),
    .req_i       (   master_req   ), 
    .rsp_o       (   master_rsp   ),
    .req_o       (   slave_req    ),
    .rsp_i       (   slave_rsp    ),
    .reg_req_i   (   cfg_req      ),
    .reg_rsp_o   (   cfg_rsp      ),
    .irq_o       (                ),
    .rst_req_o   (                )
);

  //-----------------------------------
  // TB
  //-----------------------------------

    initial begin : proc_axi_master
      automatic axi_file_master_t axi_file_master = new(master_dv);
      axi_file_master.reset();
      axi_file_master.load_files($sformatf("/scratch/chaol/slave_unit/slv_guard/test/stimuli/axi_rt_reads.txt"), $sformatf("/scratch/chaol/slave_unit/slv_guard/test/stimuli/axi_rt_writes.txt"));
    
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
  
  // initial begin
  //   automatic axi_drv_t axi_master =  new(master_dv);
  //   //automatic axi_drv_t axi_slave  =  new(slave_dv);

  //   automatic axi_drv_t::ax_beat_t ax_beat= new;
  //   automatic axi_drv_t::b_beat_t  b_beat = new;
  //   automatic axi_drv_t::r_beat_t  r_beat = new;
  //   automatic axi_drv_t::w_beat_t  w_beat = new;
    
  //   axi_master.reset_master();
    
    // ax_beat.ax_id = 10;
    // ax_beat.ax_addr = 'h1000;
    // ax_beat.ax_len = 4; // 5 beats
    // ax_beat.ax_size = 2; // 0 means 1 bytes , 2 means 4 bytes
    // ax_beat.ax_burst = 4;
    // ax_beat.ax_lock = 0;
    // ax_beat.ax_cache = 2;
    // ax_beat.ax_prot = '0;
    // ax_beat.ax_qos = '0;
    // ax_beat.ax_region = '0;
    // ax_beat.ax_atop = '0;
    // ax_beat.ax_user = '0;
    
    // w_beat.w_data = 'h1138a5dd;
    // w_beat.w_strb = 'h2c;
    // w_beat.w_user = '0;
    // w_beat.w_last = '0;

    // w_beat.w_data = 'h2238a5dd;
    // w_beat.w_strb = 'h2c;
    // w_beat.w_user = '0;
    // w_beat.w_last = '0;

    // w_beat.w_data = 'h3338a5dd;
    // w_beat.w_strb = 'h2c;
    // w_beat.w_user = '0;
    // w_beat.w_last = '0;

    // w_beat.w_data = 'h4438a544;
    // w_beat.w_strb = 'h2c;
    // w_beat.w_user = '0;
    // w_beat.w_last = '0;

    // w_beat.w_data = 'h5538a555;
    // w_beat.w_strb = 'h2c;
    // w_beat.w_user = '0;
    // w_beat.w_last = '1;


  //   // wait for config
  //   @(posedge rst_n);
  //   @(posedge clk);
  //   @(posedge guard_configured);
  //   repeat (5) @(posedge clk);

  //   axi_master.send_aw(ax_beat);
  //   axi_master.send_w(w_beat);
  //   axi_master.recv_b(b_beat);
  // // 
  // end

  // initial begin
  //   automatic axi_rand_slave_t axi_rand_slave = new(slave_dv);
  //   axi_rand_slave.reset();
  //   @(posedge rst_n);
  //   axi_rand_slave.run();
  // end


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

    // budget from aw_valid to aw_ready
    reg_drv.send_write(32'h0000_0004, 32'h0000_0010, 8'hf, reg_error); 
    // budget from aw_valid to w_valid of first word
    reg_drv.send_write(32'h0000_0008, 32'h0000_00f0, 8'hff, reg_error);
    // budget from w_valid to w_ready
    reg_drv.send_write(32'h0000_000c, 32'h0000_00a0, 8'hff, reg_error); 
    // budget from w_valid to w_last
    reg_drv.send_write(32'h0000_0010, 32'h0000_0010, 8'hff, reg_error);
    // budget from w_last to b_valid
    reg_drv.send_write(32'h0000_0014, 32'h0000_0010, 8'hff, reg_error); 
    // budget from w_last to b_ready
    reg_drv.send_write(32'h0000_0018, 32'h0000_0100, 8'hff, reg_error);

    // budget from ar_valid to ar_ready
    reg_drv.send_write(32'h0000_001c, 32'h0000_0001, 4'hf, reg_error); 
    // budget from ar_valid to r_valid of first word
    reg_drv.send_write(32'h0000_0020, 32'h0000_0001, 4'h1, reg_error);
    // budget from r_valid to r_ready
    reg_drv.send_write(32'h0000_0024, 32'h0000_0001, 4'h1, reg_error); 
    // budget from r_valid to r_last
    reg_drv.send_write(32'h0000_0028, 32'h0000_0001, 4'h1, reg_error);

    repeat (5) @(posedge clk);

    // config is done
    guard_configured = 1;
    $stop();
  end

endmodule