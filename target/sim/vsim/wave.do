onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group top -expand /tb_slv_guard/i_slv_guard_top/req_i
add wave -noupdate -group top -expand -subitemconfig {/tb_slv_guard/i_slv_guard_top/rsp_o.r -expand} /tb_slv_guard/i_slv_guard_top/rsp_o
add wave -noupdate -group top -expand /tb_slv_guard/i_slv_guard_top/req_o
add wave -noupdate -group top -expand -subitemconfig {/tb_slv_guard/i_slv_guard_top/rsp_i.r -expand} /tb_slv_guard/i_slv_guard_top/rsp_i
add wave -noupdate -group top /tb_slv_guard/i_slv_guard_top/reg_req_i
add wave -noupdate -group top /tb_slv_guard/i_slv_guard_top/reg_rsp_o
add wave -noupdate -group top /tb_slv_guard/i_slv_guard_top/clk_i
add wave -noupdate -group top /tb_slv_guard/i_slv_guard_top/rst_ni
add wave -noupdate -group top /tb_slv_guard/i_slv_guard_top/guard_ena_i
add wave -noupdate -group top /tb_slv_guard/i_slv_guard_top/rst_stat_i
add wave -noupdate -group top /tb_slv_guard/i_slv_guard_top/irq_o
add wave -noupdate -group top /tb_slv_guard/i_slv_guard_top/rst_req_o
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/clk_i
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/rst_ni
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/wr_en_i
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/budget
add wave -noupdate -group wr -expand -subitemconfig {/tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/mst_req_i.aw -expand} /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/mst_req_i
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/slv_rsp_i
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/reset_clear_i
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/reset_req_o
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/irq_o
add wave -noupdate -group wr -expand -subitemconfig {{/tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/id_track_d[0]} -expand} /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/id_track_d
add wave -noupdate -group wr -expand -subitemconfig {{/tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/id_track_q[0]} -expand} /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/id_track_q
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/match_in_id_valid
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/id_table_free
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/idx_matches_in_id
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/idx_rsp_id
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/match_in_id
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/oup_id
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/id_table_free_idx
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/match_in_idx
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/rsp_idx
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/oup_req
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/reset_req
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/reset_req_q
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/irq
add wave -noupdate -group wr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/timeout
add wave -noupdate -group tb /tb_slv_guard/cfg_req
add wave -noupdate -group tb /tb_slv_guard/cfg_rsp
add wave -noupdate -group tb /tb_slv_guard/clk
add wave -noupdate -group tb /tb_slv_guard/rst_n
add wave -noupdate -group tb /tb_slv_guard/irq
add wave -noupdate -group tb /tb_slv_guard/rst_stat
add wave -noupdate -group tb /tb_slv_guard/master_req
add wave -noupdate -group tb /tb_slv_guard/master_rsp
add wave -noupdate -group tb /tb_slv_guard/slave_req
add wave -noupdate -group tb /tb_slv_guard/slave_rsp
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/clk_i
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/rst_ni
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/slv_req_i
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/slv_resp_o
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/mst_req_o
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/mst_resp_i
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/wr_free
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/rd_free
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/rd_push_inp_id
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/wr_free_oup_id
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/rd_free_oup_id
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/both_free_oup_id
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/wr_push_oup_id
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/rd_push_oup_id
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/wr_exists_id
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/rd_exists_id
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/wr_exists
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/rd_exists
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/wr_exists_full
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/rd_exists_full
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/wr_full
add wave -noupdate -group remap /tb_slv_guard/i_slv_guard_top/i_id_remap/rd_full
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/wr_en_i
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/full_i
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/txn_budget
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/id_exists_i
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/rsp_idx_i
add wave -noupdate -group txn_mgr -expand /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/mst_req_i
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/slv_rsp_i
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/no_in_id_match_i
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/id_table_free_idx_i
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/match_in_idx_i
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/timeout
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/reset_req
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/oup_req
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/oup_id
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/match_in_id
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/match_in_id_valid
add wave -noupdate -group txn_mgr /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/id_track_q
add wave -noupdate -group txn_mgr -expand -subitemconfig {{/tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/id_track_d[0]} -expand} /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_txn_manager/id_track_d
add wave -noupdate -group lookup {/tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/gen_idx_lookup[0]/i_wr_id_lookup/match_in_id_valid}
add wave -noupdate -group lookup {/tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/gen_idx_lookup[0]/i_wr_id_lookup/match_in_id}
add wave -noupdate -group lookup {/tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/gen_idx_lookup[0]/i_wr_id_lookup/rsp_id}
add wave -noupdate -group lookup -expand {/tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/gen_idx_lookup[0]/i_wr_id_lookup/id_track_q_i}
add wave -noupdate -group lookup {/tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/gen_idx_lookup[0]/i_wr_id_lookup/idx_matches_in_id_o}
add wave -noupdate -group lookup {/tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/gen_idx_lookup[0]/i_wr_id_lookup/idx_rsp_id_o}
add wave -noupdate -group id_free -expand -subitemconfig {{/tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_id_free/id_track_q[0]} -expand} /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_id_free/id_track_q
add wave -noupdate -group id_free /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_id_free/id_free_o
add wave -noupdate -expand -group id_free_lzc /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_id_free_lzc/in_i
add wave -noupdate -expand -group id_free_lzc /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_id_free_lzc/cnt_o
add wave -noupdate -expand -group id_free_lzc /tb_slv_guard/i_slv_guard_top/i_write_monitor_unit/i_wr_id_free_lzc/empty_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/clk_i
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/rst_ni
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/axi_req_i
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/axi_rsp_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/mon_w_valid_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/mon_w_addr_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/mon_w_data_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/mon_w_id_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/mon_w_user_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/mon_w_beat_count_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/mon_w_last_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/mon_r_valid_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/mon_r_addr_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/mon_r_data_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/mon_r_id_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/mon_r_user_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/mon_r_beat_count_o
add wave -noupdate -expand -group mem /tb_slv_guard/i_tx_axi_sim_mem/mon_r_last_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {290 ns} 1} {{Cursor 2} {394 ns} 0} {{Cursor 3} {145 ns} 0}
quietly wave cursor active 3
configure wave -namecolwidth 178
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {1156 ns}
