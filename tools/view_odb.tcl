if {![info exists ::env(CURRENT_ODB)] || $::env(CURRENT_ODB) eq ""} {
    puts stderr "CURRENT_ODB is not set."
    exit 1
}

puts "Reading OpenROAD database at '$::env(CURRENT_ODB)'..."
if {[catch {read_db $::env(CURRENT_ODB)} errmsg]} {
    puts stderr $errmsg
    exit 1
}
