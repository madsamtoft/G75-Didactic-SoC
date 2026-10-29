# Vivado is the platform launcher; its environment also supplies the XSim tools.
set script_dir [file dirname [file normalize [info script]]]
set root [file normalize $script_dir/../..]
source $script_dir/sources.tcl

proc xsim_write {path contents} {
    set fd [open $path w]
    puts $fd $contents
    close $fd
}

proc xsim_exec {tool args} {
    set executable [auto_execok $tool]
    if {$executable eq ""} {error "$tool is unavailable; source your Vivado settings64 script"}
    puts "Running $tool $args"
    if {[catch {exec {*}$executable {*}$args >@ stdout 2>@ stderr} message]} {
        error "$tool failed: $message (see [pwd]/$tool.log)"
    }
}

proc xsim_validate_vcd {path} {
    set fd [open $path r]
    set signals 0
    set timestamps 0
    while {[gets $fd line] >= 0} {
        if {[string match {$var *} $line]} {set signals 1}
        if {[regexp {^#[0-9]+$} $line]} {set timestamps 1}
        if {$signals && $timestamps} {break}
    }
    close $fd
    if {!$signals || !$timestamps} {error "VCD contains no signals/timestamps: $path (check VCD_SCOPE)"}
}

proc xsim_main {root script_dir argv} {
    set defaults [dict create TOP tb_student_ss ACC_LANG sv BUILD_DIR $root/build TESTCASE blink \
        FAST_UART 1 SIM_UART_MODEL 1 BYPASS_UART 0 SANITY_CHECK 0 TIME all IMAGE pattern.pgm \
        GENERICS {} VCD_SCOPE {} VCD_DEPTH 1 CHECK_ONLY 0]
    foreach {key value} $argv {
        if {![dict exists $defaults $key]} {error "Unknown simulation option: $key"}
    }
    if {[llength $argv] % 2} {error "Simulation options must be KEY VALUE pairs"}
    set config [dict merge $defaults $argv]
    dict with config {}
    if {$TOP ni {tb_student_ss tb_didactic tb_xsim_smoke}} {error "Unsupported SIM_TOP: $TOP"}
    if {![string is integer -strict $VCD_DEPTH] || $VCD_DEPTH < 0} {error "VCD_DEPTH must be a nonnegative integer"}
    if {$TIME ne "all" && ![regexp {^[0-9]+([.][0-9]+)?(fs|ps|ns|us|ms|s)$} $TIME]} {
        error "SIM_TIME must be all or a duration such as 1us"
    }
    set build [file normalize $BUILD_DIR]
    set output [file join $build xsim $TOP $ACC_LANG]
    dict set config OUTPUT $output
    if {$VCD_SCOPE eq ""} {dict set config VCD_SCOPE /*}
    set sources [xsim_sources $root $config]
    set owner $build/xsim/.didactic-xsim
    if {[file exists $build/xsim]} {
        if {![file isfile $owner] || [string trim [join [xsim_read_lines $owner] "\n"]] ne $root} {
            error "Refusing to use unowned simulation directory: $build/xsim"
        }
    }
    file mkdir $output
    xsim_write $owner $root
    set manifest {}
    foreach kind {vhdl sv includes defines generics} {
        foreach entry [dict get $sources $kind] {lappend manifest "$kind $entry"}
    }
    xsim_write $output/sources.txt [join $manifest "\n"]
    puts "XSim top: $TOP; output: $output"
    puts "Sources: [llength [dict get $sources sv]] SystemVerilog, [llength [dict get $sources vhdl]] VHDL-2008"
    if {$CHECK_ONLY} {return}

    file mkdir $output/images $output/runtime/sim/stdout
    if {$TOP eq "tb_didactic"} {
        # The active TB hardcodes ../build/sw; stage firmware beside its private
        # runtime cwd so no RTL edits or administrator-only Windows symlinks are needed.
        set firmware_test $TESTCASE
        foreach generic [dict get $sources generics] {
            if {[regexp {^TESTCASE=(.+)$} $generic -> value]} {set firmware_test $value}
        }
        if {![regexp {^[a-zA-Z0-9_-]+$} $firmware_test]} {error "TESTCASE must be a firmware name, not a path"}
        set hex [file join $build sw $firmware_test.hex]
        if {![file isfile $hex]} {error "Firmware missing: $hex (run make build_test TEST=$firmware_test first)"}
        file mkdir $output/runtime/build/sw
        file copy -force $hex $output/runtime/build/sw/$firmware_test.hex
    }
    foreach name {waveform.vcd simulation.done xvlog.log xvhdl.log xelab.log xsim.log} {
        file delete -force $output/$name
    }
    cd $output
    # Response files preserve Bender's source order and avoid Windows command limits.
    foreach {kind tool flag} {vhdl xvhdl --2008 sv xvlog --sv} {
        set files [dict get $sources $kind]
        if {![llength $files]} {continue}
        set lines {}
        foreach path $files {lappend lines "\"[string map [list \\ \\\\ \" \\\"] $path]\""}
        xsim_write $output/$kind.f [join $lines "\n"]
        set options [list $flag --work didactic_lib --log $tool.log]
        if {$kind eq "sv"} {
            foreach path [dict get $sources includes] {lappend options -i $path}
            foreach define [dict get $sources defines] {lappend options -d $define}
        }
        xsim_exec $tool {*}$options -f $output/$kind.f
    }
    set options [list didactic_lib.$TOP --debug typical --mt off --snapshot didactic_sim --log xelab.log]
    foreach generic [dict get $sources generics] {lappend options --generic_top $generic}
    xsim_exec xelab {*}$options
    xsim_write $output/run-config.tcl "[list set xsim_config $config]\n[list source $script_dir/simulate.tcl]"
    # Keep assertions enabled. Stop on error so the Tcl script can finalize VCD.
    # XSim interprets -tclbatch as a Tcl list of paths, not a single path.
    xsim_exec xsim didactic_sim --onerror stop --onfinish stop --log xsim.log --tclbatch [list $output/run-config.tcl]
    set log [join [xsim_read_lines $output/xsim.log] "\n"]
    # Some XSim releases return zero even after HDL errors. Check diagnostics as
    # well as the child exit code and the marker written after close_vcd.
    if {[regexp -nocase -line {^\s*(error|fatal|failure):|\$stop called} $log]} {
        error "XSim reported an HDL error/assertion failure or unsupported \$stop; see $output/xsim.log"
    }
    if {![file exists $output/simulation.done] || ![file exists $output/waveform.vcd] || [file size $output/waveform.vcd] == 0} {
        error "XSim did not finalize VCD successfully; see $output/xsim.log"
    }
    xsim_validate_vcd $output/waveform.vcd
    puts "Simulation completed; VCD: $output/waveform.vcd"
}

if {[catch {xsim_main $root $script_dir $argv} message options]} {
    puts stderr "XSim flow failed: $message"
    exit 1
}
exit 0
