/// counter unit for each read transaction 
module write_counter_unit #(
  parameter int unsigned LatencyWidth = 32'd0,  // can be up to the max one
  parameter type         latency_t    = logic[LatencyWidth-1:0]
)(
  input  logic       clk_i,
  input  logic       rst_ni,

  input  logic       ena_ar_i,
  input  logic       ena_r_i,

  input  logic       clear_arvld_arrdy_i,
  input  logic       clear_arvld_rvld__i,
  input  logic       clear_rvld_rrdy_i,
  input  logic       clear_rvld_rlast_i,

  output  budget_t   latency_arvld_arrdy_o,
  output  budget_t   latency_arvld_rvld__o,
  output  budget_t   latency_rvld_rrdy_o,
  output  budget_t   latency_rvld_rlast_o
);

  
  // --------------------------------------------------------------------
  // "AR_VALID to AR_READY" Tracking and "AR_VALID to R_VALID" Tracking 
  // --------------------------------------------------------------------
  localparam latency_t static_delta_one = 'd1;

  delta_counter #(
      .WIDTH              ( BudgetWidth ),
      .STICKY_OVERFLOW    ( 1'b0        ) 
  ) i_delta_counter_arvld_arrdy (
    .clk_i,        
    .rst_ni,     
    .clear_i   ( clear_arvld_arrdy_i    ),  // On timeout or completion
    .en_i      ( ena_aw_i               ),  // Enable counter
    .load_i    ( 1'b0                   ),  // Not loading a value, so keep at 0
    .down_i    ( 1'b0                   ),  // Counting up
    .delta_i   ( static_delta_one       ),  // Increment by 1
    .d_i       ( /* NOT CONNECTED */    ),  // Only for reload      
    .q_o       ( latency_arvld_arrdy_o  ),            
    .overflow_o( /* NOT CONNECTED */    )      
  );
  
  delta_counter #(
      .WIDTH              ( BudgetWidth ),
      .STICKY_OVERFLOW    ( 1'b0        ) 
  ) i_delta_counter_arvld_rvld (
    .clk_i,        
    .rst_ni,     
    .clear_i   ( clear_arvld_rvld_i     ),  
    .en_i      ( ena_aw_i               ),  
    .load_i    ( 1'b0                   ),  
    .down_i    ( 1'b0                   ),  
    .delta_i   ( static_delta_one       ),  
    .d_i       ( /* NOT CONNECTED */    ),        
    .q_o       ( latency_arvld_rvld_o   ),            
    .overflow_o( /* NOT CONNECTED */    )      
  );
    
  // --------------------------------------------------------------
  // "R_VALID to R_READY" Tracking AND "R_VALID to R_LAST" Tracking 
  // --------------------------------------------------------------
  
  delta_counter #(
      .WIDTH              ( BudgetWidth ),
      .STICKY_OVERFLOW    ( 1'b0        ) 
  ) i_delta_counter_arvld_rvld (
    .clk_i,        
    .rst_ni,     
    .clear_i   ( clear_arvld_rvld_i     ),  
    .en_i      ( ena_aw_i               ),  
    .load_i    ( 1'b0                   ),  
    .down_i    ( 1'b0                   ),  
    .delta_i   ( static_delta_one       ),  
    .d_i       ( /* NOT CONNECTED */    ),       
    .q_o       ( latency_arvld_rvld_o   ),            
    .overflow_o( /* NOT CONNECTED */    )      
  );
  
  delta_counter #(
      .WIDTH              ( BudgetWidth ),
      .STICKY_OVERFLOW    ( 1'b0        ) 
  ) i_delta_counter_arvld_rvld (
    .clk_i,        
    .rst_ni,     
    .clear_i   ( clear_arvld_rvld_i     ),  
    .en_i      ( ena_aw_i               ),  
    .load_i    ( 1'b0                   ),  
    .down_i    ( 1'b0                   ),  
    .delta_i   ( static_delta_one       ),  
    .d_i       ( /* NOT CONNECTED */    ),     
    .q_o       ( latency_arvld_rvld_o   ),            
    .overflow_o( /* NOT CONNECTED */    )      
  );

endmodule