
module txn_manager #(
  parameter int unsigned MaxWrTxns  = 1,
  parameter int unsigned HtCapacity = 1,
  parameter int unsigned PrescalerDiv = 1,
  parameter type linked_data_t  = logic,
  parameter type head_tail_t    = logic,
  parameter type ht_idx_t       = logic,
  parameter type ld_idx_t       = logic,
  parameter type req_t          = logic,
  parameter type rsp_t          = logic,
  parameter type id_t           = logic,
  parameter type accu_cnt_t     = logic,
  parameter type hw2reg_t       = logic,
  parameter type reg2hw_t       = logic
)(
  input  logic                  wr_en_i,
  input  logic                  inp_gnt,
  input  logic [2:0]            budget_write,
  input  accu_cnt_t             accum_burst_length,
  input  logic                  reset_req_q,
  input  logic                  id_exists_i,
  input  ht_idx_t               rsp_idx_i,
  input  req_t                  mst_req_i,
  input  rsp_t                  slv_rsp_i,
  input  logic                  no_out_id_match_i,
  input  logic                  no_in_id_match_i,
  input  ht_idx_t               match_out_idx_i,
  input  ht_idx_t               head_tail_free_idx_i,
  input  ht_idx_t               match_in_idx_i,
  input  ld_idx_t               oup_data_free_idx_i,
  input  ld_idx_t               linked_data_free_idx_i,
  output logic                  timeout,
  output logic                  reset_req,
  output logic                  oup_req,
  output id_t                   oup_id,
  output id_t                   match_in_id,
  output id_t                   match_out_id,
  output logic                  match_in_id_valid, 
  output logic                  match_out_id_valid,
  output logic                  oup_data_valid,
  output logic                  oup_data_popped,
  output logic                  oup_ht_popped,
  input  head_tail_t [HtCapacity-1:0] head_tail_q,
  output head_tail_t [HtCapacity-1:0] head_tail_d,
  input  linked_data_t [MaxWrTxns-1:0] linked_data_q,
  output linked_data_t [MaxWrTxns-1:0] linked_data_d,
  output hw2reg_t                        hw2reg_o,
  input  reg2hw_t                        reg2hw_i
);

  accu_cnt_t txn_budget;
  
  // Transaction states handling
  always_comb begin
    match_in_id         = '0;
    match_out_id        = '0;
    match_in_id_valid   = 1'b0;
    match_out_id_valid  = 1'b0;
    head_tail_d         = head_tail_q;
    linked_data_d       = linked_data_q;
    oup_data_valid      = 1'b0;
    oup_data_popped     = 1'b0;
    oup_ht_popped       = 1'b0;
    oup_id              = '0;
    oup_req             = 1'b0;
    timeout             = '0;
    reset_req           = reset_req_q;
    hw2reg_o.irq.unwanted_wr_resp.d = reg2hw_i.irq.unwanted_wr_resp.q;
    hw2reg_o.irq.txn_id.d       = reg2hw_i.irq.txn_id.q;
    hw2reg_o.irq.wr_timeout.d   = reg2hw_i.irq.wr_timeout.q;
    hw2reg_o.irq.irq.d          = reg2hw_i.irq.irq.q;
    hw2reg_o.irq_addr.d         = reg2hw_i.irq_addr.q;
    hw2reg_o.reset.d            = reg2hw_i.reset.q;
    hw2reg_o.latency_write.d    = reg2hw_i.latency_write.q;

    // Transaction states handling
    for ( int i = 0; i < MaxWrTxns; i++ ) begin : proc_wr_txn_states
      if (!linked_data_q[i].free ) begin 
        if (linked_data_q[i].counter == 0 ) begin 
          timeout = 1'b1; 
          hw2reg_o.irq.wr_timeout.d = 1'b1;
          reset_req = 1'b1;
          hw2reg_o.reset.d = 1'b1;
          //hw2reg_o.irq_addr.d = linked_data_q[i].metadata.addr;
          hw2reg_o.irq.txn_id.d = linked_data_q[i].metadata.id;
          hw2reg_o.irq.irq.d = 1'b1;
        end
        if( slv_rsp_i.b_valid && mst_req_i.b_ready && !timeout ) begin 
          if( id_exists_i ) begin
             //if no match yet, determine if there's a match and update status
            linked_data_d[ i].found_match = (linked_data_q[i].metadata.id == slv_rsp_i.b.id) && (head_tail_q[rsp_idx_i].head == i);
            //linked_data_d[ID] = 1;
          end else begin 
            hw2reg_o.irq.unwanted_wr_resp.d = 1'b1;
            hw2reg_o.reset.d = 1'b1;
            reset_req = 1'b1;
            hw2reg_o.irq.irq.d = 1'b1;
          end
        end 

       if ( linked_data_q[i].found_match) begin
       // if ( found_match_q ) begin
          oup_req = 1; 
          oup_id = linked_data_q[i].metadata.id;
          //oup_id = linked_data_q[found_id_q].metadata.id;
          hw2reg_o.latency_write.d = linked_data_q[i].counter;
          linked_data_d[i] = '0;
          linked_data_d[i].counter = '0;
          linked_data_d[i].free = 1'b1;
        end
      end
    end

    if (reset_req) begin 
      for (int i = 0; i < MaxWrTxns; i++) begin
        if (!linked_data_q[i].free) begin // remove check and force all to 0
          oup_req = 1;
          oup_id = linked_data_q[i].metadata.id; // remove
          linked_data_d[i] = '0;
          linked_data_d[i].counter = '0;
          linked_data_d[i].free = 1'b1;
        end
      end
    end

    // Dequeue 
    if (oup_req) begin : proc_txn_dequeue
      match_out_id = oup_id;
      match_out_id_valid = 1'b1;
      // only if oup_id exists in ht table
      if (!no_out_id_match_i) begin // nonsense!!!!!!
        oup_data_valid = 1'b1;
        oup_data_popped = 1;
        // Set free bit of linked data entry, all other bits are don't care.
        linked_data_d[head_tail_q[match_out_idx_i].head]          = '0;
        linked_data_d[head_tail_q[match_out_idx_i].head].free     = 1'b1;
        // If it is the last cell of this ID
        if (head_tail_q[match_out_idx_i].head == head_tail_q[match_out_idx_i].tail) begin
          oup_ht_popped = 1'b1;
          head_tail_d[match_out_idx_i] = '{free: 1'b1, default: '0};
        end else begin
          head_tail_d[match_out_idx_i].head = linked_data_q[head_tail_q[match_out_idx_i].head].next;
        end
      end 
    end

    // Enqueue
    if (wr_en_i && inp_gnt ) begin : proc_txn_enqueue
      match_in_id = mst_req_i.aw.id;
      match_in_id_valid = 1'b1;  
      txn_budget =  accum_burst_length + (mst_req_i.aw.len +1) >> $clog2(PrescalerDiv) + 1; // need to count itself
      // If output data was popped for this ID, which lead the head_tail to be popped,
      // then repopulate this head_tail immediately.
      if (oup_ht_popped && (oup_id == mst_req_i.aw.id)) begin // Remove second condition
        head_tail_d[match_out_idx_i] = '{
          id: mst_req_i.aw.id,
          head: oup_data_free_idx_i,
          tail: oup_data_free_idx_i,
          free: 1'b0
        };
        linked_data_d[oup_data_free_idx_i] = '{
          metadata: '{id: mst_req_i.aw.id, len: mst_req_i.aw.len},
          //metadata:mst_req_i.aw,
          counter: txn_budget,
          found_match: 0,
          next: '0,
          free: 1'b0
        };
      end else if (no_in_id_match_i) begin
        // Else, if no head_tail corresponds to the input id, and no same ID just popped.
        // 3 cases
        if (oup_ht_popped) begin
          head_tail_d[match_out_idx_i] = '{
            id: mst_req_i.aw.id,
            head: oup_data_free_idx_i,
            tail: oup_data_free_idx_i,
            free: 1'b0
          };
          linked_data_d[oup_data_free_idx_i] = '{
            metadata: '{id: mst_req_i.aw.id, len: mst_req_i.aw.len},
            //metadata:mst_req_i.aw,
            counter: txn_budget,
            found_match: 0,
            next: '0,
            free: 1'b0
          };
        end else begin
          if (oup_data_popped) begin
            head_tail_d[head_tail_free_idx_i] = '{
              id: mst_req_i.aw.id,
              head: oup_data_free_idx_i,
              tail: oup_data_free_idx_i,
              free: 1'b0
            };
            linked_data_d[oup_data_free_idx_i] = '{
              metadata: '{id: mst_req_i.aw.id, len: mst_req_i.aw.len},
              //metadata:mst_req_i.aw,
              counter: txn_budget,
              found_match: 0,
              next: '0,
              free: 1'b0
            };
          end else begin
            head_tail_d[head_tail_free_idx_i] = '{
              id: mst_req_i.aw.id,
              head: linked_data_free_idx_i,
              tail: linked_data_free_idx_i,
              free: 1'b0
            };
            linked_data_d[linked_data_free_idx_i] = '{
              metadata: '{id: mst_req_i.aw.id, len: mst_req_i.aw.len},
              //metadata:mst_req_i.aw,
              counter: txn_budget,
              found_match: 0,
              next: '0,
              free: 1'b0
            };
          end
        end
      end else begin
        // Otherwise append it to the existing ID subqueue.
        if (oup_data_popped) begin
          linked_data_d[head_tail_q[match_in_idx_i].tail].next = oup_data_free_idx_i;
          head_tail_d[match_in_idx_i].tail = oup_data_free_idx_i;
          linked_data_d[oup_data_free_idx_i] = '{
            metadata: '{id: mst_req_i.aw.id, len: mst_req_i.aw.len},
            //metadata:mst_req_i.aw,
            counter: txn_budget,
            found_match: 0,
            next: '0,
            free: 1'b0
          };
        end else begin
          linked_data_d[head_tail_q[match_in_idx_i].tail].next = linked_data_free_idx_i;
          head_tail_d[match_in_idx_i].tail = linked_data_free_idx_i;
          linked_data_d[linked_data_free_idx_i] = '{
            metadata: '{id: mst_req_i.aw.id, len: mst_req_i.aw.len},
            //metadata:mst_req_i.aw,
            counter: txn_budget,
            found_match: 0,
            next: '0,
            free: 1'b0
          };
        end
      end
    end
  end

  // assign POPPED = ....;
  // assign PNT_TO_POP = ....;

  // assign linked_data_pnt = (POPPED) ? PNT_TO_POP : FIRST_FREE;
endmodule
