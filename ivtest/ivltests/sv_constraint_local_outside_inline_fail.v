// The `local::' qualifier is legal only within an inline constraint block
// (IEEE 1800-2017/2023 18.7.1, footnote 43 on the constraint_block_item
// production). Used in a plain class-body `constraint' declaration, it
// must be rejected -- not silently fall through to an ordinary property
// reference (which would silently drop the caller-scope-selection
// semantics that give `local::' its whole meaning).
module main;
  class c;
    rand integer x;
    constraint c1 { x < local::x; }
  endclass
endmodule
