# Vivado is the platform launcher; its environment also supplies the XSim tools.
set script_dir [file dirname [file normalize [info script]]]
set root [file normalize $script_dir/../..]
source $script_dir/sources.tcl
source $script_dir/images.tcl

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
    set timestamp 0
    set changed 0
    set values [dict create]
    while {[gets $fd line] >= 0} {
        if {[string match {$var *} $line]} {set signals 1}
        if {[regexp {^#([0-9]+)$} $line -> time]} {set timestamp $time}
        if {[regexp {^([01xXzZ])(.+)$} $line -> value id] ||
            [regexp {^[bBrR]([^ ]+) (.+)$} $line -> value id]} {
            if {$timestamp > 0 && [dict exists $values $id] && [dict get $values $id] ne $value} {set changed 1}
            dict set values $id $value
        }
        if {$signals && $changed} {break}
    }
    close $fd
    if {!$signals || !$changed} {error "VCD contains no signal transitions after time zero: $path"}
}

proc xsim_main {root script_dir argv} {
    set defaults [dict create TOP tb_student_ss ACC_LANG sv BUILD_DIR $root/build TESTCASE blink \
        FAST_UART 1 SIM_UART_MODEL 1 BYPASS_UART 0 SANITY_CHECK 0 TIME all IMAGE pattern.pgm \
        SOURCE_LIST {} GENERICS {} VCD_SCOPE {} VCD_DEPTH 1 CHECK_ONLY 0]
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
    set image [xsim_image_path $TOP [dict get $sources generics] $output/runtime/sim]
    # An older result must never satisfy this run's image validation.
    if {$image ne ""} {
        file mkdir [file dirname $image]
        file delete -force $image
    }
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
        set binary [file join $build sw $firmware_test.bin]
        file delete -force $output/firmware.bin
        if {[file isfile $binary]} {file copy -force $binary $output/firmware.bin}
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
    set options [list didactic_lib.$TOP --debug wave --O3 --mt off --snapshot didactic_sim --log xelab.log]
    foreach generic [dict get $sources generics] {lappend options --generic_top $generic}
    xsim_exec xelab {*}$options
    # HDL $fwrite is frequently unbuffered. Keep high-volume writes on the
    # simulator's local filesystem instead of Colima's macOS shared mount.
    set temporary [file tempfile scratch didactic-xsim-]
    close $temporary
    file delete $scratch
    file mkdir $scratch/runtime
    if {[file isdirectory $output/runtime/build]} {file copy $output/runtime/build $scratch/runtime/build}
    file mkdir $scratch/runtime/sim/stdout $scratch/images
    set scratch_image [xsim_image_path $TOP [dict get $sources generics] $scratch/runtime/sim]
    if {$scratch_image ne ""} {file mkdir [file dirname $scratch_image]}
    set runtime_config $config
    dict set runtime_config OUTPUT $scratch
    xsim_write $output/run-config.tcl "[list set xsim_config $runtime_config]\n[list source $script_dir/simulate.tcl]"
    file copy $output/xsim.dir $scratch/xsim.dir
    file copy $output/run-config.tcl $scratch/run-config.tcl
    cd $scratch/runtime/sim
    set failed [catch {
        xsim_exec xsim didactic_sim --xsimdir ../../xsim.dir --onerror stop --onfinish stop --log $scratch/xsim.log --tclbatch ../../run-config.tcl
    } message options]
    cd $output
    # Preserve diagnostics even when the simulator fails. Never copy xsim.dir.
    foreach name {xsim.log waveform.vcd simulation.done images} {
        if {[file exists $scratch/$name]} {
            file delete -force $output/$name
            file copy -force $scratch/$name $output/$name
        }
    }
    foreach path [glob -nocomplain $scratch/runtime/sim/*] {
        set destination $output/runtime/sim/[file tail $path]
        file delete -force $destination
        file copy -force $path $destination
    }
    # Also collect images when SIM_GENERICS overrides the default output path.
    if {$scratch_image ne "" && $scratch_image ne $image && [file isfile $scratch_image]} {
        file copy -force $scratch_image $image
    }
    file delete -force $scratch
    if {$failed} {return -options $options $message}
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
    if {$TIME eq "all" && ![regexp {\$finish called at time} $log]} {
        error "Simulation returned without the testbench finishing; see $output/xsim.log"
    }
    if {$TIME eq "all" && $image ne ""} {
        xsim_publish_image $image $root/src/tb/out_images
    }
    puts "Simulation completed; VCD: $output/waveform.vcd"
}

if {[catch {xsim_main $root $script_dir $argv} message options]} {
    puts stderr "XSim flow failed: $message"
    exit 1
}
exit 0
