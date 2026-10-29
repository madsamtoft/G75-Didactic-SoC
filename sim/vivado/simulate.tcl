# Sourced by XSim before the first run command, not by the Vivado parent.
set output [dict get $xsim_config OUTPUT]
set opened 0
set failed [catch {
    cd $output/runtime/sim
    open_vcd $output/waveform.vcd
    set opened 1
    if {![llength [get_objects -r [dict get $xsim_config VCD_SCOPE]]]} {
        error "No signals match VCD_SCOPE=[dict get $xsim_config VCD_SCOPE]"
    }
    log_vcd -level [dict get $xsim_config VCD_DEPTH] [dict get $xsim_config VCD_SCOPE]
    if {[dict get $xsim_config TIME] eq "all"} {
        run all
    } else {
        run [dict get $xsim_config TIME]
    }
} message]
if {$opened && [catch {close_vcd} close_error]} {
    set failed 1
    append message " VCD close failed: $close_error"
}
if {$failed} {
    puts stderr "ERROR: XSim run/VCD failed: $message"
} else {
    set fd [open $output/simulation.done w]
    puts $fd "VCD finalized after [dict get $xsim_config TIME]"
    close $fd
}
quit
