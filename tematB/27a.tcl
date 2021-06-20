source symul_lib.tcl

# source tematB/27a-kombinacja.tcl
source tematB/27a-absorbcja.tcl

fiber create $liczbaWierz {
	# ===================== Inicjalizacja wg założeń =====================
	switch $id {
		2 - 3 - 8 - 9 { set core 0 }
		default { set core -1 }
	}
	switch -regexp $id {
		^[2389]$ { set parent -1 }
		default { set parent 0 }
	}
	# F1 - 2, F2 - 3
	set fragment [expr 2 + [expr $id >= 5]]
	switch $id {
		0 - 1 - 5 - 7 - 10 - 11 - 12 { set children {} }
		3 - 4 - 6 - 8                { set children {1} }
		2 - 9                        { set children {1 2} }
	}

	if { $liczbaWierz == 12 } {
		# Przykład z kombinacją
		set level 2
	} else {
		# Przykład z absorbcją
		switch -regexp $id {
			^[0-5]$ { set level 2 }
			default { set level 3 }
		}
	}

	puts "lvl $id $level"

	# ===================== Algorytm =====================

	set moe_candidates_count 0
	# Infinity := 1 << 30
	set moe_candidate_weight [expr 1 << 30]
	set moe_candidate "_"
	set core_candidate_weight -1

	# Do każdej krawędzi potencajlnie nie będącej w twoim fragmencie (nie będącej
	# ani rodzicem, ani dzieckiem) wyślij komunikat <Test ID_FRAGMENTU> w celu
	# określenia czy dany wierzchołek należy do twojego fragmentu
	iterate i $stopien {
		if { $parent != $i && [lsearch $children $i] == -1 && $i != $core } {
			wyslij $i "Test $fragment"
			incr moe_candidates_count
		}
	}

	if { [llength $children ] == 0 && $parent != -1 } {
		wyslij $parent "Report $moe_candidate_weight"
	}

	set moe_candidates_count [expr $moe_candidates_count + [llength $children]]

	set connect_has_been_sent 0
	set connect_has_been_received 0
	set combine_started 0

	set other_fragment_id -1
	set original_core $core

	while {$run} {
		fiber yield

		if { $connect_has_been_received && $connect_has_been_sent && !$combine_started } {
			set combine_started 1
			# Kombinacja:
			# [x] krawędź MOE zostaje rdzeniem
			# [x] ++level
			# [x] rozpropaguj nowy poziom oraz fragment_id
			# [ ] oba fragmenty zostają przekorzenione (odwrócenie ścieżki old_core -> moe)

			set fragment [expr $fragment * $other_fragment_id]
			incr level
			if { $parent >= 0 } {
				wyslij $parent "Propagate $fragment $level"
				set parent -1
			} else {
				wyslij $original_core "Propagate $fragment $level"
			}

			foreach child $children {
				wyslij $child "Propagate $fragment $level"
			}
		}

		iterate i $stopien {
			set k [czytaj $i]
			if {$k == ""} { continue }
			puts "$id\t$i\t$k"
			switch [lindex $k 0] {
				"Test" {
					set other [lindex $k 1]
					wyslij $i "Inside [expr $fragment == $other]"
				}

				"Inside" {
					set w [lindex $wagi $i]
					if {[lindex $k 1] != 1 && $w < $moe_candidate_weight} {
						set moe_candidate $i
						set moe_candidate_weight $w
					}
					incr moe_candidates_count -1

					# Jeśli otrzymaliśmy odpowiedzi od każdego z sąsiadów,
					# to znaleźliśmy kandydata na MOE
					if {$moe_candidates_count == 0} {
						if {$parent != -1} {
							fiber yield
							wyslij $parent "Report $moe_candidate_weight"
						}
					}
				}

				"Report" {
					set w [lindex $k 1]
					if {$moe_candidate == "_" || $w < $moe_candidate_weight} {
						set moe_candidate $i
						set moe_candidate_weight $w
					}
					incr moe_candidates_count -1

					if {$moe_candidates_count == 0} {
						if {$parent != -1} {
							fiber yield
							wyslij $parent "Report $moe_candidate_weight"
						} else {
							# Znaleziono MOE w jednym z węzłów rdzenia
							if { $core_candidate_weight < 0 || $core_candidate_weight > $moe_candidate_weight} {
								wyslij $core "Core-Report $moe_candidate_weight"
							} else {
								wyslij $core "Core-Report $core_candidate_weight"
							}
						}
					}
				}

				"Core-Report" {
					set core_candidate_weight [lindex $k 1]
					if {$moe_candidates_count != 0} { continue }

					# Mamy MOE
					if {$moe_candidate_weight == $core_candidate_weight} {
						set w [lindex $wagi $moe_candidate]
						if { $moe_candidate_weight == $w } {
							wyslij $moe_candidate "Connect $fragment $level"
							set connect_has_been_sent 1
							continue
						}
						wyslij $moe_candidate "Change-Core"
						continue
					}

					if {$core_candidate_weight < $moe_candidate_weight} {
						wyslij $core "Core-Report $core_candidate_weight"
						set moe_candidate_weight $core_candidate_weight
					} else {
						wyslij $core "Core-Report $moe_candidate_weight"
					}
				}

				"Change-Core" {
					set w [lindex $wagi $moe_candidate]
					if { $w == $moe_candidate_weight } {
						# TODO Mark state as BRANCH
						wyslij $moe_candidate "Connect $fragment $level"
						set connect_has_been_sent 1
						continue
					}

					wyslij $moe_candidate "Change-Core"
				}

				"Connect" {
					set other_fragment_id [lindex $k 1]
					set other_level [lindex $k 2]

					if { $level < $other_level } {
						# czekaj aż otrzymasz Connect(_, other_level) gdzie other_level >= $level
						continue
					}

					if { $level == $other_level } {
						set connect_has_been_received 1
						set core $moe_candidate
						# connect zostanie obsłużony na początku kolejnej iteracji
						# w momencie spełniania wszystkich wymaganych warunków
						# z uwagi na wiele potencjalnych ścieżek wejścia
						continue
					}

					# TODO absorbcja
					# TODO rozkminić stany
					# [ ] nasz fragment zostaje powiększony o F1
					# [ ] przekorzenienie od nas oraz ustawienie F2_id przez MOE
					wyslij $moe_candidate "Propagate $fragment $level"
				}

				"Propagate" {
					set fragment [lindex $k 1]
					set level [lindex $k 2]

					# if { $core != -1 } {
					# }

					if { $moe_candidate != "_" } {
						set w [lindex $wagi $moe_candidate]
						if { $moe_candidate == $i && $moe_candidate_weight == $w } {
								set core $moe_candidate
						}
					}

					set idx [lsearch $children $i]
					if { $idx >= 0 } {
						set children [lreplace $children $idx $idx]
					}

					if { $core >= 0 && $moe_candidate != $core } {
						if { $core != $i } {
							wyslij $core $k
						}
						set parent $i
						set core -1
					}

					if { $parent != $i && [llength $children] > 0 } {
						set old_parent $parent
						set parent $i
						if { $old_parent != -1 } {
							lappend children $old_parent
						}
					}

					foreach child $children {
						wyslij $child $k
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

set waga(0,2) 5
set waga(1,2) 3
set waga(2,3) 2
set waga(3,4) 4
set waga(3,6) 10
set waga(4,5) 6
set waga(4,8) 1
set waga(6,7) 9
set waga(6,8) 8
set waga(8,9) 11
set waga(9,10) 7
set waga(9,11) 12

Inicjalizacja
ustaw_wagi

if { $liczbaWierz == 12 } {
	fiber_iterate { source tematB/27a-kombinacja.tcl }
} else {
	fiber_iterate { source tematB/27a-absorbcja.tcl }
}

proc vis {} {
	fiber_iterate {
		set dweight $moe_candidate_weight
		if { $dweight == [expr 1 << 30] } {
			set dweight "_"
		}

		set dparent $parent
		if { $dparent == -1 } {
			set dparent "_"
		} else {
			set dparent [lindex $sasiedzi($id) $parent]
		}

		set dl1 "$id:\tcc=$moe_candidates_count\tmoe=$moe_candidate\tw=$dweight\tp=$dparent"
		set dl2 "c=$core\tf=$fragment"
		puts "$dl1\t$dl2"
	}
	puts [fiber error]
	puts "---------------------------------------"
}

if { $liczbaWierz == 12 } {
	set iterations 12
} else {
	set iterations 15
}

iterate i $iterations {
	fiber yield
	runda
	vis
}
