package require openlane


set save_path chip_io/../..

set ::env(USE_GPIO_ROUTING_LEF) 0
prep -design chip_io -tag chip_io_lvs -overwrite

set ::env(SYNTH_DEFINES) ""
verilog_elaborate
init_floorplan
file copy -force $::env(CURRENT_DEF) $::env(TMP_DIR)/lvs.def
file copy -force $::env(CURRENT_NETLIST) $::env(TMP_DIR)/lvs.v

# ACTUAL CHIP INTEGRATION
set ::env(USE_GPIO_ROUTING_LEF) 1
prep -design chip_io -tag chip_io -overwrite

file copy designs/chip_io/runs/chip_io_lvs/tmp/merged_unpadded.lef $::env(TMP_DIR)/lvs.lef
file copy designs/chip_io/runs/chip_io_lvs/tmp/lvs.def $::env(TMP_DIR)/lvs.def
file copy designs/chip_io/runs/chip_io_lvs/tmp/lvs.v $::env(TMP_DIR)/lvs.v

set ::env(SYNTH_DEFINES) "TOP_ROUTING"
verilog_elaborate

init_floorplan

puts_info "Generating pad frame"
exec -ignorestderr python3 $::env(SCRIPTS_DIR)/padringer.py\
	--def-netlist $::env(CURRENT_DEF)\
	--design $::env(DESIGN_NAME)\
	--lefs $::env(TECH_LEF) {*}$::env(GPIO_PADS_LEF)\
	-cfg designs/chip_io/padframe.cfg\
	--working-dir $::env(TMP_DIR)\
	-o $::env(RESULTS_DIR)/floorplan/padframe.def
puts_info "Generated pad frame"

set_def $::env(RESULTS_DIR)/floorplan/padframe.def

# modify to a different file
remove_pins -input $::env(CURRENT_DEF)
remove_empty_nets -input $::env(CURRENT_DEF)

add_macro_obs \
	-defFile $::env(CURRENT_DEF) \
	-lefFile $::env(MERGED_LEF_UNPADDED) \
	-obstruction core_obs \
	-placementX 230 \
	-placementY 240 \
	-sizeWidth 3132 \
	-sizeHeight 4710 \
	-fixed 1 \
	-layerNames "met1 met2 met3 met4 met5"


li1_hack_start
global_routing
detailed_routing
li1_hack_end

label_macro_pins\
	-lef $::env(TMP_DIR)/lvs.lef\
	-netlist_def $::env(TMP_DIR)/lvs.def\
	-pad_pin_name "PAD"\
	-extra_args {-v\
	--map VDDA_PAD VDDA vdda INOUT\
	--map VSSA_PAD VSSA vssa INOUT\
	--map VCCD_PAD VCCD vccd INOUT\
	--map VSSD_PAD VSSD vssd INOUT\
	--map VDDIO_PAD VDDIO vddio INOUT\
	--map VSSIO_PAD VSSIO vssio INOUT}


run_magic

# run_magic_drc

save_views       -lef_path $::env(magic_result_file_tag).lef \
                 -def_path $::env(CURRENT_DEF) \
                 -gds_path $::env(magic_result_file_tag).gds \
		 -mag_path $::env(magic_result_file_tag).mag \
                 -maglef_path $::env(magic_result_file_tag).lef.mag \
		 -verilog_path $::env(TMP_DIR)/lvs.v \
		 -save_path $save_path \
                 -tag $::env(RUN_TAG)


run_magic_spice_export
run_lvs $::env(magic_result_file_tag).spice $::env(TMP_DIR)/lvs.v
