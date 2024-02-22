/// counter unit for each write transaction 
module write_counter_unit #(
  parameter int unsigned LatencyWidth = 32'd0,  // can be up to the max one
  parameter type         latency_t    = logic[LatencyWidth-1:0]
)(
  input  logic       clk_i,
  input  logic       rst_ni,

  input  logic       ena_aw_i,
  input  logic       ena_w_i,
  input  logic       ena_b_i,

  input  logic       clear_awvld_awrdy_i,
  input  logic       clear_awvld_wvld__i,
  input  logic       clear_wvld_wrdy_i,
  input  logic       clear_wvld_wlast_i,
  input  logic       clear_wlast_bvld_i,
  input  logic       clear_wlast_brdy_i,

  output  budget_t   latency_awvld_awrdy_o,
  output  budget_t   latency_awvld_wvld__o,
  output  budget_t   latency_wvld_wrdy_o,
  output  budget_t   latency_wvld_wlast_o,
  output  budget_t   latency_wlast_bvld_o,
  output  budget_t   latency_wlast_brdy_o
);
  
  
  // state enum of the bypass FSM
  typedef enum logic [1:0] {
    IDLE,
    ISOLATE,
    SWITCH,
    DEISOLATE
  } rt_state_e;

  // FSM state
  rt_state_e rt_state_d, rt_state_q;

  // FSM signals
  logic byp_isolate;

  // RT state
  logic rt_bypassed_d, rt_bypassed_q;

  // isolate output
  logic isolated;
  logic tail_isolated;


  // --------------------------------------------------
  // Bypass FSM
  // --------------------------------------------------
  // The bypass FSM will start in a bypassed state. The enable signal will activate it.

  always_comb begin : proc_fsm
    // default
    rt_state_d    = rt_state_q;
    rt_bypassed_d = rt_bypassed_q;
    byp_isolate   = 1'b0;

    case (rt_state_q)
      IDLE : begin
        if (rt_enable_i & rt_bypassed_q) begin
          rt_state_d = ISOLATE;
        end
        if (!rt_enable_i & !rt_bypassed_q) begin
          rt_state_d = ISOLATE;
        end
      end

      ISOLATE : begin
        byp_isolate = 1'b1;
        if (isolated) begin
          rt_state_d = SWITCH;
        end
      end

      SWITCH : begin
        byp_isolate = 1'b1;
        rt_bypassed_d = !rt_bypassed_q;
        rt_state_d = DEISOLATE;
      end

      DEISOLATE : begin
        if(!isolated) begin
          rt_state_d = IDLE;
        end
      end
    endcase
  end

  // connect output
  assign rt_bypassed_o = rt_bypassed_q;

  // state
  `FFARN(rt_state_q,    rt_state_d,    IDLE, clk_i, rst_ni)
  `FFARN(rt_bypassed_q, rt_bypassed_d, 1'b1, clk_i, rst_ni)

  // --------------------------------------------------------------------
  // "AW_VALID to AW_READY" Tracking and "AW_VALID to AW_READY" Tracking 
  // --------------------------------------------------------------------
  localparam latency_t static_delta_one = 'd1;

  delta_counter #(
      .WIDTH              ( BudgetWidth ),
      .STICKY_OVERFLOW    ( 1'b0        ) 
  ) i_delta_counter_awvld_awrdy (
    .clk_i,        
    .rst_ni,     
    .clear_i   ( clear_awvld_awrdy_i    ),  // On timeout or completion
    .en_i      ( ena_aw_i               ),  // Enable counter
    .load_i    ( 1'b0                   ),  // Not loading a value, so keep at 0
    .down_i    ( 1'b0                   ),  // Counting up
    .delta_i   ( static_delta_one       ),  // Increment by 1
    .d_i       ( /* NOT CONNECTED */    ),  // Only for reload      
    .q_o       ( latency_awvld_awrdy_o  ),            
    .overflow_o( /* NOT CONNECTED */    )      
  );
  
  delta_counter #(
      .WIDTH              ( BudgetWidth ),
      .STICKY_OVERFLOW    ( 1'b0        ) 
  ) i_delta_counter_awvld_wvld (
    .clk_i,        
    .rst_ni,     
    .clear_i   ( clear_awvld_wvld_i     ),  
    .en_i      ( ena_aw_i               ),  
    .load_i    ( 1'b0                   ),  
    .down_i    ( 1'b0                   ),  
    .delta_i   ( static_delta_one       ),  
    .d_i       ( /* NOT CONNECTED */    ),        
    .q_o       ( latency_awvld_wvld_o   ),            
    .overflow_o( /* NOT CONNECTED */    )      
  );
    
  // ----------------------------------------------------------------
  // "W_VALID to W_READY" Tracking and "W_VALID to W_LAST" Tracking 
  // ----------------------------------------------------------------
  
  delta_counter #(
      .WIDTH              ( BudgetWidth ),
      .STICKY_OVERFLOW    ( 1'b0        ) 
  ) i_delta_counter_wvld_wrdy (
    .clk_i,        
    .rst_ni,     
    .clear_i   ( clear_wvld_wrdy_i      ), 
    .en_i      ( ena_aw_i               ),  
    .load_i    ( 1'b0                   ),  
    .down_i    ( 1'b0                   ), 
    .delta_i   ( static_delta_one       ), 
    .d_i       ( /* NOT CONNECTED */    ),     
    .q_o       ( latency_wvld_wrdy_o  ),            
    .overflow_o( /* NOT CONNECTED */    )      
  );
  
  delta_counter #(
      .WIDTH              ( BudgetWidth ),
      .STICKY_OVERFLOW    ( 1'b0        ) 
  ) i_delta_counter_wvld_wlast (
    .clk_i,        
    .rst_ni,     
    .clear_i   ( clear_wvld_wlast_i     ),  
    .en_i      ( ena_aw_i               ),  
    .load_i    ( 1'b0                   ), 
    .down_i    ( 1'b0                   ), 
    .delta_i   ( static_delta_one       ),  
    .d_i       ( /* NOT CONNECTED */    ),        
    .q_o       ( latency_wvld_wlast_o   ),            
    .overflow_o( /* NOT CONNECTED */    )      
  );

  // --------------------------------------------------------------
  // "W_LAST to B_VALID" Tracking AND "W_LAST to B_READY" Tracking 
  // --------------------------------------------------------------
  
  delta_counter #(
      .WIDTH              ( BudgetWidth ),
      .STICKY_OVERFLOW    ( 1'b0        ) 
  ) i_delta_counter_wlast_bvld (
    .clk_i,        
    .rst_ni,     
    .clear_i   ( clear_wlast_bvld_i     ),  
    .en_i      ( ena_aw_i               ),  
    .load_i    ( 1'b0                   ),  
    .down_i    ( 1'b0                   ),  
    .delta_i   ( static_delta_one       ),  
    .d_i       ( /* NOT CONNECTED */    ),       
    .q_o       ( latency_wlast_bvld_o   ),            
    .overflow_o( /* NOT CONNECTED */    )      
  );
  
  delta_counter #(
      .WIDTH              ( BudgetWidth ),
      .STICKY_OVERFLOW    ( 1'b0        ) 
  ) i_delta_counter_wlast_brdy (
    .clk_i,        
    .rst_ni,     
    .clear_i   ( clear_wlast_brdy_i     ),  
    .en_i      ( ena_aw_i               ),  
    .load_i    ( 1'b0                   ),  
    .down_i    ( 1'b0                   ),  
    .delta_i   ( static_delta_one       ),  
    .d_i       ( /* NOT CONNECTED */    ),     
    .q_o       ( latency_wlast_brdy_o   ),            
    .overflow_o( /* NOT CONNECTED */    )      
  );

endmodule