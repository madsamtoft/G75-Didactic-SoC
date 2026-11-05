# The HDL testbenches write P2 images directly; VCD is not an image source.
proc xsim_image_path {top generics runtime} {
    if {$top eq "tb_student_ss"} {
        set image_key src_image
        set path_key out_image_path
    } elseif {$top eq "tb_didactic"} {
        set image_key SRC_IMAGE
        set path_key OUT_IMG_PATH
    } else {
        return {}
    }
    foreach generic $generics {
        regexp {^([^=]+)=(.*)$} $generic -> name value
        if {$name eq $image_key} {set image $value}
        if {$name eq $path_key} {set directory $value}
    }
    # Match the testbenches' removal of the final four characters (.pgm).
    set name "[string range $image 0 end-4]_result.pgm"
    return [file normalize [file join $runtime $directory $name]]
}

proc xsim_publish_image {path destination} {
    if {![file isfile $path]} {error "Testbench did not write the output image: $path"}
    set fd [open $path r]
    set contents [read $fd]
    close $fd
    regsub -all {#[^\n]*} $contents {} contents
    set tokens [regexp -all -inline {\S+} $contents]
    if {[lrange $tokens 0 3] ne {P2 352 288 255} || [llength $tokens] != 101380} {
        error "Incomplete or invalid output image (expected P2, 352x288, 255, 101376 pixels): $path"
    }
    set unknown 0
    foreach pixel [lrange $tokens 4 end] {
        if {[string equal -nocase $pixel x]} {
            incr unknown
        } elseif {![string is integer -strict $pixel] || $pixel < 0 || $pixel > 255} {
            error "Invalid output pixel '$pixel': $path"
        }
    }
    # Preserve Questa's output even when student RTL leaves pixels unwritten.
    if {$unknown} {puts "WARNING: Output contains $unknown unknown pixels; check accelerator output-buffer writes: $path"}
    file mkdir $destination
    set published [file join $destination [file tail $path]]
    if {[file normalize $path] ne [file normalize $published]} {
        file copy -force $path $published
    }
    puts "Output image: $published (simulation copy: $path)"
}
