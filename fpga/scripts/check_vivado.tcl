# Lightweight runtime/mount check: no project creation, synthesis or implementation.
if {[catch {
    puts "Vivado: [version -short]"
    puts "Working directory: [pwd]"
    foreach name {BUILD_DIR PROJECT ACC_LANG TEST} {
        if {![info exists ::env($name)] || $::env($name) eq ""} {
            error "Required environment variable is missing: $name"
        }
        puts "$name=$::env($name)"
    }
    foreach list_file {flist.f flist_bscane.f includes.f} {
        set fd [open $list_file r]
        set entries [split [string trim [read $fd]] "\n"]
        close $fd
        foreach entry $entries {
            set entry [string trim $entry]
            if {$entry ne "" && ![file exists $entry]} {
                error "Missing path from $list_file: $entry (fetch dependencies and regenerate file lists if needed)"
            }
        }
    }
    set output [file join $::env(BUILD_DIR) vivado-check.txt]
    set fd [open $output w]
    puts $fd "Vivado [version -short]; cwd=[pwd]; PROJECT=$::env(PROJECT); ACC_LANG=$::env(ACC_LANG); TEST=$::env(TEST)"
    close $fd
    puts "Runtime check passed; host output: $output"
} message]} {
    puts stderr "Runtime check failed: $message"
    exit 1
}
exit 0
