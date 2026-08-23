// Strict negative: solve-before may not order the size of a non-rand
// container. The size remains legal state in ordinary constraints.
class nonrand_darray_size_bad_order;
  rand int unsigned control;
  int unsigned data[];
  constraint bad_c { solve control before data.size; }
endclass

module test;
  nonrand_darray_size_bad_order item;
endmodule
