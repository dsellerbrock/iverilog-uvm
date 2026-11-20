// The `local::' qualifier is legal only within an inline constraint block
// (IEEE 1800 18.7.1 and Annex A, footnote 43 in 2017 and 48 in 2023).
// Used in a plain class-body `constraint' declaration, it
// must be rejected -- not silently fall through to an ordinary property
// reference (which would silently drop the caller-scope-selection
// semantics that give `local::' its whole meaning).
module main;
  class c;
    rand integer x;
    constraint c1 { x < local::x; }
  endclass
endmodule
