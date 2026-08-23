// Strict negative: a paren-less dynamic-array size retains its owning
// property's randc qualifier in solve-before ordering.
class randc_darray_size_bad_order;
  rand int unsigned control;
  randc byte unsigned data[];
  constraint bad_c { solve control before data.size; }
endclass

module test;
  randc_darray_size_bad_order item;
endmodule
