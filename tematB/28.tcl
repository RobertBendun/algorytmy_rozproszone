source symul_lib.tcl

# Fragment
set liczbaWierz 8
set sasiedzi(0) {4 1}
set sasiedzi(1) {2 0 5}
set sasiedzi(2) {1 3}
set sasiedzi(3) {2}
set sasiedzi(4) {5 6 0}
set sasiedzi(5) {4 1 7}

set sasiedzi(6) {7 4}
set sasiedzi(7) {6 5}

fiber create $liczbaWierz {
	set mark 0
	set parent -1
	set children {}

	# r == 0
	if {$id == 0} {
		set mark 1
		iterate i $stopien {
			wyslij $i "search"
		}
	}

	while {$run} {
		fiber yield
		if {$mark} { continue }
		iterate i $stopien {
			set k [czytaj $i]
			if {$k==""} {continue}
			puts $k
			switch [lindex $k 0] {
				"search" {
					set parent $i
					fiber yield
					iterate j $stopien {
						if {$j != $parent} {
							wyslij $j "search"
						}
					}
					set mark 1
				}
			}
		}
	}
}

Inicjalizacja

proc wizualizacja {} {
	fiber_iterate {
		puts "$id: parent: $parent"
	}
}

iterate i 6 {
	fiber yield; runda; wizualizacja
	puts [fiber error]
}
