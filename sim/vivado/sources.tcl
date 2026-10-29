# Read a fresh Bender manifest with the same targets as Questa.
proc xsim_read_lines {path} {
    set fd [open $path r]
    set lines [split [read $fd] "\n"]
    close $fd
    set result {}
    foreach line $lines {
        set line [string trim $line]
        if {$line ne "" && ![string match {#*} $line]} {lappend result $line}
    }
    return $result
}

proc xsim_sources {root config} {
    dict with config {}
    if {$ACC_LANG ni {sv vhdl}} {error "ACC_LANG must be sv or vhdl"}
    foreach name {FAST_UART SIM_UART_MODEL BYPASS_UART CHECK_ONLY} {
        if {[dict get $config $name] ni {0 1}} {error "$name must be 0 or 1"}
    }
    if {$SANITY_CHECK ne "0"} {
        error "The active tb_didactic_V1.sv and tb_student_ss have no DM_SANITY_TESTCASES parameter; SANITY_CHECK must be 0"
    }
    set vhdl {}
    set includes {}
    set defines {}
    set generics {}
    switch -- $TOP {
        tb_student_ss {
            set files [list $root/src/tb/tb_student_ss.sv $root/src/rtl/Student_area_0.sv]
            set generics [list src_image=$IMAGE src_image_path=$root/src/tb/src_images out_image_path=../../images]
        }
        tb_didactic {
            set files {}
            foreach entry [xsim_read_lines $SOURCE_LIST] {
                if {[string match {+incdir+*} $entry]} {
                    lappend includes [string range $entry 8 end]
                } elseif {[string match {+define+*} $entry]} {
                    lappend defines [string range $entry 8 end]
                } elseif {[string match {-*} $entry] || [string match {+*} $entry]} {
                    error "Unsupported Bender option: $entry"
                } else {
                    # Headers are included by RTL, not compilation units. In
                    # particular, compiling prim_assert_dummy_macros.svh here
                    # would replace live assertions with empty macro bodies.
                    if {[file extension $entry] eq ".svh"} {continue}
                    if {$SIM_UART_MODEL && [file tail $entry] eq "apb_uart.sv"} {continue}
                    lappend files $entry
                }
            }
            if {$SIM_UART_MODEL} {lappend files $root/src/tb/apb_uart_sim.sv}
            foreach path {vendor/lowrisc_ip/dv/sv/dv_utils vendor/lowrisc_ip/ip/prim/rtl rtl} {
                lappend includes $root/vendor_ips/ibex/$path
            }
            lappend defines RVFI INC_ASSERT USE_UART USE_SPI XSIM
            foreach {name macro} {FAST_UART SIM_FAST_UART SIM_UART_MODEL SIM_UART_MODEL BYPASS_UART BYPASS_UART} {
                if {[dict get $config $name]} {lappend defines $macro}
            }
            set generics [list TESTCASE=$TESTCASE SRC_IMAGE=$IMAGE SRC_IMG_PATH=$root/src/tb/src_images OUT_IMG_PATH=../../images]
        }
        tb_xsim_smoke {set files [list $root/sim/vivado/tests/tb_xsim_smoke.sv]}
        default {error "Unsupported SIM_TOP: $TOP (use tb_student_ss, tb_didactic or tb_xsim_smoke)"}
    }
    if {$TOP ne "tb_xsim_smoke"} {
        if {$ACC_LANG eq "vhdl"} {
            lappend vhdl $root/src/rtl/pixel_acc_vhd.vhd
            lappend files $root/src/rtl/pixel_acc_vhd_wrapper.sv
        } else {
            lappend files $root/src/rtl/pixel_acc.sv
        }
    }
    foreach path [concat $vhdl $files $includes] {
        if {![file exists $path]} {error "Missing simulation input: $path (fetch dependencies or regenerate sim file lists)"}
    }
    # Overrides are a Tcl list of NAME=VALUE entries, not executable Tcl code.
    foreach generic $GENERICS {
        if {![regexp {^([a-zA-Z_][a-zA-Z_0-9]*)=(.+)$} $generic -> name value]} {
            error "Invalid SIM_GENERICS entry: $generic (expected NAME=VALUE)"
        }
        set filtered {}
        foreach existing $generics {
            if {![string match "$name=*" $existing]} {lappend filtered $existing}
        }
        set generics [concat $filtered [list $generic]]
    }
    # A trailing separator in a string generic can break XSim's generated C++
    # scope string. A final dot denotes the same directory without that ending.
    set normalized {}
    foreach generic $generics {
        if {[regexp {^(SRC_IMG_PATH|OUT_IMG_PATH|src_image_path|out_image_path)=(.*)/$} $generic]} {
            append generic .
        }
        lappend normalized $generic
    }
    set generics $normalized
    return [dict create sv $files vhdl $vhdl includes $includes defines $defines generics $generics]
}
