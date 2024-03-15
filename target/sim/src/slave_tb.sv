// one master and one slave first
`timescale 1 ns/1 ns
`include "axi/typedef.svh"
`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"

module slv_guard_tb
 #(
  parameter int unsigned NumSub            = 32'd1,
  parameter int unsigned MaxTxnsPerId      = 32'd4,
  parameter int unsigned MaxWrUniqIds      = 32'd4,
  parameter int unsigned MaxWrTxns         = 32'd4,
  parameter int unsigned MaxRdUniqIds      = 32'd4,
  parameter int unsigned MaxRdTxns         = 32'd4,
  parameter int unsigned CntWidth          = 32'd8
);
  import reg_test::;

  /// timing parameters
  localparam time SYS_TCK       = 8ns;
  localparam time SYS_TA        = 2ns;
  localparam time SYS_TT        = 6ns;

  /// Register interface parameters
  localparam int AW_REGBUS           = 32;
  localparam int DW_REGBUS           = 32;
  localparam int unsigned STRB_WIDTH = DW_REGBUS/8;

  /// Dependent parameters
  localparam int unsigned StrbWidth     = DataWidth / 8;
  localparam int unsigned OffsetWidth   = $clog2(StrbWidth);

  /// AXI4+ATOP typedefs
  typedef logic [AddrWidth-1:0]   addr_t;
  typedef logic [AxiIdWidth-1:0]  id_t;
  typedef logic [UserWidth-1:0]   user_t;
  typedef logic [StrbWidth-1:0]   strb_t;
  typedef logic [DataWidth-1:0]   data_t;
  typedef logic [TFLenWidth-1:0]  tf_len_t;
  
  `AXI_TYPEDEF_AW_CHAN_T(axi_aw_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(axi_w_chan_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(axi_b_chan_t, id_t, user_t) 
  `AXI_TYPEDEF_AR_CHAN_T(axi_ar_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(axi_r_chan_t, data_t, id_t, user_t) 

  `AXI_TYPEDEF_REQ_T(axi_req_t, axi_aw_chan_t, axi_w_chan_t, axi_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_rsp_t, axi_b_chan_t, axi_r_chan_t)

  /// Regsiter bus typedefs
  typedef logic [AW_REGBUS-1:0]   reg_bus_addr_t;
  typedef logic [DW_REGBUS-1:0]   reg_bus_data_t;
  typedef logic [STRB_WIDTH-1:0]  reg_bus_strb_t;

  `REG_BUS_TYPEDEF_ALL(reg_bus, reg_bus_addr_t, reg_bus_data_t, reg_bus_strb_t)

  // clocking block
  clk_rst_gen #(
    .ClkPeriod    ( SYS_TCK   ),
    .RstClkCycles ( 1         )
  ) i_clk_rst_gen (
    .clk_o        ( clk     ),
    .rst_no       ( rst_n   )
  );

  // Instance of slv_guard with one subordinate
  slv_guard #(
    .MaxTxnsPerId ( MaxTxnsPerId ),
    .MaxWrUniqIds ( MaxWrUniqIds ),
    .MaxRdUniqIds ( MaxRdUniqIds ),
    .MaxWrTxns    ( MaxWrTxns    ),
    .MaxRdTxns    ( MaxRdTxns    ),
    .CntWidth     ( CntWidth     ),
    .req_t        ( axi_req_t    ), 
    .rsp_t        ( axi_rsp_t    ),
    .reg_req_t    ( reg_req_t    ), 
    .reg_rsp_t    ( reg_rsp_t    )
) i_slv_guard (
    .clk_i       (   clk      ),
    .rst_ni      (   rst_n    ),
    .guard_ena_i (   1        ),
    .req_i       (            ), 
    .rsp_o       (            ),
    .req_o       (            ),
    .rsp_i       (            ),
    .reg_req_i   (            ),
    .reg_rsp_o   (            ),
    .irq_o       (            ),
    .rst_req_o   (            )
);


initial begin
    wait(rst_n == 1); 
    @(posedge clk);
    
    req_i.aw.valid <= 1'b1;
    req_i.aw.addr  <= 32'hDEADBEEF; 
    req_i.aw.id    <= 4'd1;
    
    @(posedge clk);
    req_i[0].aw.valid <= 1'b0;
end

always @(posedge clk) begin
    if (req_i[0].aw.valid && !rsp_i[0].aw.ready) begin
        // simulate some delay 
        #10; // Delay for 10 clock cycles
        rsp_i[0].aw.ready <= 1'b1;
        @(posedge clk);
        rsp_i[0].aw.ready <= 1'b0;
    end
end


