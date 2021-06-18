source symul_lib.tcl

set liczbaWierz 8

# Fragment 1
set sasiedzi(0) {1 4}
set sasiedzi(1) {0 2 3}
set sasiedzi(2) {1}
set sasiedzi(3) {1 6}
set sasiedzi(4) {0}

# Fragement 2
set sasiedzi(5) {6 7}
set sasiedzi(6) {5 3}
set sasiedzi(7) {5}


fiber create $liczbaWierz {
	set moe_src {3 6}

  # fid - identifykator fragmentu
	# zakładamy, że identyfikator jest liczbą pierwszą lub
	# iloczynem identyfikatorów fragmentów na niego się składających
  switch -regexp $id {
    [0-4] { set fid 2 }
    [5-7] { set fid 3 }
  }

  switch -regexp $id {
    # Korzeń
    [05] {
      set parent -1
      set children [lrange {0 1} 0 $stopien]
    }

    # Nie-korzeń
    default {
      set parent 0
      if {$stopien == 1} {
        set children {}
      } else {
        set children [lrange {1 2} 0 $stopien]
      }
    }
  }

  set moe 0
  foreach x $moe_src {
    if {$x == $id} { set moe 1 }
  }

  # ----------- Algorytm -----------

  proc chparent {ch} {
		global id
    wyslij $ch "chparent $id"
  }

  proc chparent_iter {} {
    global children
		foreach child $children {
      chparent $child
    }
  }

  if {$moe > 0} {
		if {$parent >= 0} {
			set children [lappend $children $parent]
			set parent -1
		}
		chparent_iter

		# Tworzymy nowy identyfikator dla połączonego fragmentu
		for {set i 0} {$i < $stopien} {incr i} {
			set found 0
			foreach child $children {
				if {$child == $i} { set found 1; break }
			}
			if {$parent == $i} { set found 1 }
			if {$found == 0} {
				wyslij $i "multiply $fid $id"
			}
		}
  }

  while {$run} {
		fiber yield

    iterate i $stopien {
      set k [czytaj $i]
      if {$k == ""} { continue }
      switch [lindex $k 0] {
				"multiply" {
					set m [lindex $k 1]
					set fid [expr $fid * $m]

					foreach child $children {
						if {$i != $child} { wyslij $child "multiply $m $id" }
					}

					if { $parent > 0 && $parent != $i } { wyslij $parent "multiply $m $id" }
				}

        "chparent" {
					# sanity check
					if {$moe > 0} { continue }

          # Jeśli już rodzic jest rodzicem nie ma potrzeby zmiany
          if {$parent == $i} {
            continue
          }

          if {$parent < 0} {
            # Usuń dziecko, które zostanie rodzicem
            set idx [lsearch $children $i]
            set parent [lindex $children $idx]
            set children [lreplace $children $idx $idx]

            # Poinformuj dzieci o zmianie (wiemy, że nadawca nie zostanie poinformowany
            # bo przestał być dzieckiem)
            chparent_iter
            continue
          }

					if {[llength $children] > 0} {
						set old_parent $parent
						set idx [lsearch $children $i]
						set parent [lindex $children $idx]
						set children [lreplace $children $idx $idx $old_parent]
					}
					chparent_iter
        }
      }
    }
	 }
}

Inicjalizacja

proc wizualizacja {} {
  fiber_iterate {
    puts "$id: fid=$fid moe=$moe parent=$parent children=$children"
  }
}

iterate i 5 {
  fiber yield; runda; wizualizacja
  puts [fiber error]
}
