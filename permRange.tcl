proc permRange {n} {
  proc uniform {n}  {
    return [expr int(floor([tcl::mathfunc::rand] * $n))]
  }

  set p {}
  iterate i $n { lappend p $i }
  iterate i $n {
    set j [expr $i + [uniform [expr $n - $i]]]
    set t [lindex $p $i]
    lset p $i [lindex $p $j]
    lset p $j $t
  }

  return $p
}
