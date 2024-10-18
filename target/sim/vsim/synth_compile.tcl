# This script was generated automatically by bender.
set ROOT "/scratch/chaol/slave_unit/perID/axi_monitor"
set search_path_initial $search_path

set search_path $search_path_initial

if {0 == [analyze -format sv \
    -define { \
        TARGET_MONITOR_SYNTH \
        TARGET_RTL \
        TARGET_SYNOPSYS \
        TARGET_SYNTHESIS \
    } \
    [list \
        "$ROOT/.bender/git/checkouts/tech_cells_generic-0ae34f908dcf517f/src/rtl/tc_sram.sv" \
        "$ROOT/.bender/git/checkouts/tech_cells_generic-0ae34f908dcf517f/src/rtl/tc_sram_impl.sv" \
    ]
]} {return 1}

set search_path $search_path_initial

if {0 == [analyze -format sv \
    -define { \
        TARGET_MONITOR_SYNTH \
        TARGET_RTL \
        TARGET_SYNOPSYS \
        TARGET_SYNTHESIS \
    } \
    [list \
        "$ROOT/.bender/git/checkouts/tech_cells_generic-0ae34f908dcf517f/src/rtl/tc_clk.sv" \
    ]
]} {return 1}

set search_path $search_path_initial

if {0 == [analyze -format sv \
    -define { \
        TARGET_MONITOR_SYNTH \
        TARGET_RTL \
        TARGET_SYNOPSYS \
        TARGET_SYNTHESIS \
    } \
    [list \
        "$ROOT/.bender/git/checkouts/tech_cells_generic-0ae34f908dcf517f/src/deprecated/pulp_clock_gating_async.sv" \
        "$ROOT/.bender/git/checkouts/tech_cells_generic-0ae34f908dcf517f/src/deprecated/cluster_clk_cells.sv" \
        "$ROOT/.bender/git/checkouts/tech_cells_generic-0ae34f908dcf517f/src/deprecated/pulp_clk_cells.sv" \
    ]
]} {return 1}

set search_path $search_path_initial
lappend search_path "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/include"

if {0 == [analyze -format sv \
    -define { \
        TARGET_MONITOR_SYNTH \
        TARGET_RTL \
        TARGET_SYNOPSYS \
        TARGET_SYNTHESIS \
    } \
    [list \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/binary_to_gray.sv" \
    ]
]} {return 1}

set search_path $search_path_initial
lappend search_path "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/include"

if {0 == [analyze -format sv \
    -define { \
        TARGET_MONITOR_SYNTH \
        TARGET_RTL \
        TARGET_SYNOPSYS \
        TARGET_SYNTHESIS \
    } \
    [list \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/cb_filter_pkg.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/cc_onehot.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/cdc_reset_ctrlr_pkg.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/cf_math_pkg.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/clk_int_div.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/credit_counter.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/delta_counter.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/ecc_pkg.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/edge_propagator_tx.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/exp_backoff.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/fifo_v3.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/gray_to_binary.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/isochronous_4phase_handshake.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/isochronous_spill_register.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/lfsr.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/lfsr_16bit.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/lfsr_8bit.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/lossy_valid_to_stream.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/mv_filter.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/onehot_to_bin.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/plru_tree.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/passthrough_stream_fifo.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/popcount.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/rr_arb_tree.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/rstgen_bypass.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/serial_deglitch.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/shift_reg.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/shift_reg_gated.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/spill_register_flushable.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_demux.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_filter.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_fork.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_intf.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_join_dynamic.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_mux.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_throttle.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/sub_per_hash.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/sync.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/sync_wedge.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/unread.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/read.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/addr_decode_dync.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/cdc_2phase.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/cdc_4phase.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/clk_int_div_static.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/addr_decode.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/addr_decode_napot.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/multiaddr_decode.sv" \
    ]
]} {return 1}

set search_path $search_path_initial
lappend search_path "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/include"

if {0 == [analyze -format sv \
    -define { \
        TARGET_MONITOR_SYNTH \
        TARGET_RTL \
        TARGET_SYNOPSYS \
        TARGET_SYNTHESIS \
    } \
    [list \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/cb_filter.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/cdc_fifo_2phase.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/clk_mux_glitch_free.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/counter.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/ecc_decode.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/ecc_encode.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/edge_detect.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/lzc.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/max_counter.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/rstgen.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/spill_register.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_delay.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_fifo.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_fork_dynamic.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_join.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/cdc_reset_ctrlr.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/cdc_fifo_gray.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/fall_through_register.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/id_queue.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_to_mem.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_arbiter_flushable.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_fifo_optimal_wrap.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_register.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_xbar.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/cdc_fifo_gray_clearable.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/cdc_2phase_clearable.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/mem_to_banks_detailed.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_arbiter.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/stream_omega_net.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/mem_to_banks.sv" \
    ]
]} {return 1}

set search_path $search_path_initial
lappend search_path "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/include"

if {0 == [analyze -format sv \
    -define { \
        TARGET_MONITOR_SYNTH \
        TARGET_RTL \
        TARGET_SYNOPSYS \
        TARGET_SYNTHESIS \
    } \
    [list \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/deprecated/clock_divider_counter.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/deprecated/clk_div.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/deprecated/find_first_one.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/deprecated/generic_LFSR_8bit.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/deprecated/generic_fifo.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/deprecated/prioarbiter.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/deprecated/pulp_sync.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/deprecated/pulp_sync_wedge.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/deprecated/rrarbiter.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/deprecated/clock_divider.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/deprecated/fifo_v2.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/deprecated/fifo_v1.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/edge_propagator_ack.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/edge_propagator.sv" \
        "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/src/edge_propagator_rx.sv" \
    ]
]} {return 1}

set search_path $search_path_initial
lappend search_path "$ROOT/.bender/git/checkouts/apb-29cf0c01a8ae60ee/include"
lappend search_path "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/include"

if {0 == [analyze -format sv \
    -define { \
        TARGET_MONITOR_SYNTH \
        TARGET_RTL \
        TARGET_SYNOPSYS \
        TARGET_SYNTHESIS \
    } \
    [list \
        "$ROOT/.bender/git/checkouts/apb-29cf0c01a8ae60ee/src/apb_pkg.sv" \
        "$ROOT/.bender/git/checkouts/apb-29cf0c01a8ae60ee/src/apb_intf.sv" \
        "$ROOT/.bender/git/checkouts/apb-29cf0c01a8ae60ee/src/apb_err_slv.sv" \
        "$ROOT/.bender/git/checkouts/apb-29cf0c01a8ae60ee/src/apb_regs.sv" \
        "$ROOT/.bender/git/checkouts/apb-29cf0c01a8ae60ee/src/apb_cdc.sv" \
        "$ROOT/.bender/git/checkouts/apb-29cf0c01a8ae60ee/src/apb_demux.sv" \
    ]
]} {return 1}

set search_path $search_path_initial
lappend search_path "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/include"
lappend search_path "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/include"

if {0 == [analyze -format sv \
    -define { \
        TARGET_MONITOR_SYNTH \
        TARGET_RTL \
        TARGET_SYNOPSYS \
        TARGET_SYNTHESIS \
    } \
    [list \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_pkg.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_intf.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_atop_filter.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_burst_splitter.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_bus_compare.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_cdc_dst.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_cdc_src.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_cut.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_delayer.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_demux_simple.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_dw_downsizer.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_dw_upsizer.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_fifo.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_id_remap.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_id_prepend.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_isolate.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_join.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_lite_demux.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_lite_dw_converter.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_lite_from_mem.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_lite_join.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_lite_lfsr.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_lite_mailbox.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_lite_mux.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_lite_regs.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_lite_to_apb.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_lite_to_axi.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_modify_address.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_mux.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_rw_join.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_rw_split.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_serializer.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_slave_compare.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_throttle.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_to_detailed_mem.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_cdc.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_demux.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_err_slv.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_dw_converter.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_from_mem.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_id_serialize.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_lfsr.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_multicut.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_to_axi_lite.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_to_mem.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_zero_mem.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_interleaved_xbar.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_iw_converter.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_lite_xbar.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_xbar_unmuxed.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_to_mem_banked.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_to_mem_interleaved.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_to_mem_split.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_xbar.sv" \
        "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/src/axi_xp.sv" \
    ]
]} {return 1}

set search_path $search_path_initial
lappend search_path "$ROOT/.bender/git/checkouts/apb-29cf0c01a8ae60ee/include"
lappend search_path "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/include"
lappend search_path "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/include"
lappend search_path "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/include"

if {0 == [analyze -format sv \
    -define { \
        TARGET_MONITOR_SYNTH \
        TARGET_RTL \
        TARGET_SYNOPSYS \
        TARGET_SYNTHESIS \
    } \
    [list \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/reg_intf.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/vendor/lowrisc_opentitan/src/prim_subreg_arb.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/vendor/lowrisc_opentitan/src/prim_subreg_ext.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/apb_to_reg.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/axi_lite_to_reg.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/axi_to_reg_v2.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/periph_to_reg.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/reg_cdc.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/reg_cut.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/reg_demux.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/reg_err_slv.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/reg_filter_empty_writes.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/reg_mux.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/reg_to_apb.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/reg_to_mem.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/reg_to_tlul.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/reg_to_axi.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/reg_uniform.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/vendor/lowrisc_opentitan/src/prim_subreg_shadow.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/vendor/lowrisc_opentitan/src/prim_subreg.sv" \
        "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/src/deprecated/axi_to_reg.sv" \
    ]
]} {return 1}

set search_path $search_path_initial
lappend search_path "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/include"
lappend search_path "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/include"
lappend search_path "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/include"
lappend search_path "$ROOT/include"

if {0 == [analyze -format sv \
    -define { \
        TARGET_MONITOR_SYNTH \
        TARGET_RTL \
        TARGET_SYNOPSYS \
        TARGET_SYNTHESIS \
    } \
    [list \
        "$ROOT/source/registers/slv_guard_reg_pkg.sv" \
        "$ROOT/source/registers/slv_guard_reg_top.sv" \
        "$ROOT/source/wr_counter.sv" \
        "$ROOT/source/rd_counter.sv" \
        "$ROOT/source/id_lookup.sv" \
        "$ROOT/source/id_free.sv" \
        "$ROOT/source/wr_txn_manager.sv" \
        "$ROOT/source/rd_txn_manager.sv" \
        "$ROOT/source/reset_handler.sv" \
        "$ROOT/source/write_guard.sv" \
        "$ROOT/source/read_guard.sv" \
        "$ROOT/source/slv_guard_top.sv" \
    ]
]} {return 1}

set search_path $search_path_initial
lappend search_path "$ROOT/.bender/git/checkouts/axi-cd1ad815a37e282b/include"
lappend search_path "$ROOT/.bender/git/checkouts/common_cells-ad49e78d2e53620a/include"
lappend search_path "$ROOT/.bender/git/checkouts/register_interface-81dc5c395d6ef500/include"
lappend search_path "$ROOT/include"

if {0 == [analyze -format sv \
    -define { \
        TARGET_MONITOR_SYNTH \
        TARGET_RTL \
        TARGET_SYNOPSYS \
        TARGET_SYNTHESIS \
    } \
    [list \
        "$ROOT/source/slv_pkg.sv" \
        "$ROOT/source/monitor_wrap.sv" \
    ]
]} {return 1}

set search_path $search_path_initial
