source symul_lib.tcl

# Fragment
set liczbaWierz 8
set sasiedzi(0) {1 4}
set sasiedzi(1) {0 2 5}
set sasiedzi(2) {1 3}
set sasiedzi(3) {2}
set sasiedzi(4) {0 5 6}
set sasiedzi(5) {1 4 7}

# Poza fragmentem
set sasiedzi(6) {4 7}
set sasiedzi(7) {5 6}

fiber create $liczbaWierz {
	# -1 - root
	switch $id {
		0 { set parent -1; set children {0 1} }
		1 { set parent 0; set children {1 2} }
		2 { set parent 0; set children {1} }
		3 { set parent 0; set children {} }
		4 { set parent 0; set children {} }
		5 { set parent 0; set children {} }
	}

	switch -regexp $id {
		[0-5] { set in_tree 1 }
		default { set in_tree 0 }
	}

	set candidate "_"
	set candidate_weight [expr 1 << 30]
	set candidates_count 0
	set others {}
	set moe 0

	# -------- ALGORITHM -----------

	if {$in_tree} {
		iterate i $stopien {
			if { $parent != $i && [lsearch $children $i] == -1 } {
				wyslij $i "foreign? $id"
				incr candidates_count
			}
		}

		if {$candidates_count == 0} {
			set candidates_count [llength $children]
			if {$candidates_count == 0 && $parent != -1} {
				wyslij $parent "empty"
			}
		}
	}

	while {$run} {
		fiber yield
		iterate i $stopien {
			set k [czytaj $i]
			if {$k == ""} { continue }
			switch [lindex $k 0] {
				"empty" {
					incr candidates_count -1

					if {$candidates_count == 0 && $parent != -1} {
						fiber yield
						if {$candidate == "_"} { wyslij $parent "empty"
						} else {                 wyslij $parent "cand $candidate_weight" }
					}
				}

				"cand" {
					set w [lindex $k 1]
					if {$candidate == "_" || $w < $candidate_weight} {
						set candidate $i
						set candidate_weight $w
					}

					incr candidates_count -1
					if {$candidates_count == 0} {
						if {$parent != -1} {
							fiber yield
							wyslij $parent "cand $candidate_weight"
						} else {
							foreach child $children {
								wyslij $child "set $candidate_weight"
							}
						}
					}
				}

				"set" {
					set candidate_weight [lindex $k 1]
					foreach child $children {
						wyslij $child "set $candidate_weight"
					}
					foreach o $others {
						if {[lindex $wagi $o] == $candidate_weight} {
							set moe 1
							wyslij $o "set_moe"
						}
					}

					if {$moe == 0} {
						set candidate $i
					}
				}

				"set_moe" {
					set moe 1
				}

				"foreign?" {
					wyslij $i "foreign [expr $in_tree == 0]"
				}

				"foreign" {
					set w [lindex $wagi $i]

					if {[lindex $k 1] == 1 && $w < $candidate_weight} {
						set candidate $i
						set candidate_weight $w
						set others [lappend $others $i]
					}
					incr candidates_count -1
					if {$candidates_count == 0} {
						if {$parent != -1} {
							fiber yield
							wyslij $parent "cand $candidate_weight"
						}
					}
				}
			}
		}
	}
}

proc ustaw_wagi {} {
  global sasiedzi liczbaWierz waga
  iterate i $liczbaWierz {
    set ww {}
    foreach s $sasiedzi($i) {
      if {[info exists waga($i,$s)]} {
        set w $waga($i,$s)
      } elseif {[info exists waga($s,$i)]} {
        set w $waga($s,$i)
      } else {
        set w 0
      }
      lappend ww $w
    }
    fiber_eval $i "set wagi {$ww}"
  }
}

set waga(0,1) 1
set waga(0,4) 2
set waga(1,2) 4
set waga(2,3) 9
set waga(1,5) 3
set waga(4,5) 6
set waga(4,6) 5
set waga(5,7) 7


Inicjalizacja
ustaw_wagi


proc wizualizacja {} {
	fiber_iterate {
		puts "$id: moe=$moe candidate=$candidate count=$candidates_count weight=$candidate_weight"
	}
}

iterate i 10 {
	fiber yield; runda; wizualizacja
	puts [fiber error]
}
