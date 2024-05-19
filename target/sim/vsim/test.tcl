if {[catch { vlog -incr \
    -override_timescale 1ns/1ps \
    +notimingchecks +nospecify \
    "/usr/pack/gf-12-kgf/arm/gf/12lpplus/sc7p5mcpp84_base_lvt_c14/r5p0/verilog/sc7p5mcpp84_12lpplus_base_lvt_c14.v" \
    "/scratch/chaol/slave_unit/slv_guard/monitor-synth/synopsys/out/monitor_sspg_0p495v_125c_1ns/netlist_monitor.v"
}]} {return 1}