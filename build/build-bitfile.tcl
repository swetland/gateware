
source config.tcl

synth_design -top top -part $PART

write_checkpoint -force ./post-synth-checkpoint.dcp
report_utilization -file ./post-synth-utilization.txt
report_timing -sort_by group -max_paths 5 -path_type summary -file ./post-synth-timing.txt

opt_design
power_opt_design
place_design
write_checkpoint -force ./post-place-checkpoint.dcp

phys_opt_design
route_design
write_checkpoint -force ./post-route-checkpoint.dcp

report_utilization -file ./post-route-utilization.txt
report_timing_summary -file ./post-route-timing-summary.txt
report_timing -sort_by group -max_paths 100 -path_type summary -file ./post-route-timing.txt
report_drc -file ./post-route-drc.txt
write_verilog -force ./post-route-netlist.v
write_xdc -no_fixed_only -force ./post-route-constr.xdc

set_property BITSTREAM.GENERAL.COMPRESS True [current_design]
write_bitstream -force -bin_file $BITFILE

