source symul_lib.tcl

set liczbaWierz 12

# Konwencja:
# - pierwszy wierzchołek to rodzic opisywanego wierzchołka
set sasiedzi(0) {2}
set sasiedzi(1) {2}
set sasiedzi(2) {3 0 1}
set sasiedzi(3) {2 4 6}
set sasiedzi(4) {3 5 8}
set sasiedzi(5) {4}
set sasiedzi(6) {8 7 3}
set sasiedzi(7) {6}
set sasiedzi(8) {9 6 4}
set sasiedzi(9) {8 10 11}
set sasiedzi(10) {9}
set sasiedzi(11) {9}

fiber create $liczbaWierz {
	# ===================== Inicjalizacja wg założeń =====================
	switch $id {
		2 - 3 - 8 - 9 { set core 0 }
		default { set core -1 }
	}
	switch -regexp $id {
		[2389] { set parent -1 }
		default { set parent 0 }
	}
	# F1 - 2, F2 - 3
	set fragment [expr 2 + [expr $id >= 5]]
	switch $id {
		0 - 1 - 5 - 7 - 10 - 11 { set children {} }
		3 - 4 - 6 - 8           { set children {1} }
		2 - 9                   { set children {1 2} }
	}

	set level 2

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

	while {$run} {
		fiber yield

		if { $connect_has_been_received && $connect_has_been_sent && !$combine_started } {
			puts "Hellope"
			set combine_started 1
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
						if { $moe_candidate_weight == $w }
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
					set other_level [lindex $k 1]

					if { $level < $other_level } {
						# czekaj aż otrzymasz Connect(_, other_level) gdzie other_level >= $level
						continue
					}

					if { $level == $other_level } {
						# Kombinacja:
						# [ ] krawędź MOE zostaje rdzeniem
						# [ ] oba fragmenty zostają przekorzenione (odwrócenie ścieżki old_core -> moe)
						# [ ] ++level
						# [ ] rozpropaguj nowy poziom oraz fragment_id

						if { !$connect_has_been_sent } {
							# czekaj aż wyśle Connect
							set connect_has_been_received 1
							continue
						}
						continue
					}

					# TODO absorbcja
					# TODO rozkminić stany
					# [ ] nasz fragment zostaje powiększony o F1
					# [ ] przekorzenienie od nas oraz ustawienie F2_id przez MOE
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

proc vis {} {
	fiber_iterate {
		set dweight $moe_candidate_weight
		if { $dweight == [expr 1 << 30] } {
			set dweight "_"
		}
		puts "$id:\tcandid=$moe_candidates_count\tmoe=$moe_candidate\tweight=$dweight\tparent=$parent"
	}
	puts [fiber error]
	puts "---------------------------------------"
}

iterate i 15 {
	fiber yield
	runda
	vis
}
