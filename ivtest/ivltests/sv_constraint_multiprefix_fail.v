class invalid_multiprefix_reductions;
  rand int a[0:1][-2:-1][4:6];
  int idx;
  constraint partial_rank_c { a[0].sum() == 0; }
  constraint out_of_bounds_later_prefix_c { a[0][3].sum() == 0; }
  constraint nonconstant_later_prefix_c { a[0][idx].sum() == 0; }
endclass

module test;
  invalid_multiprefix_reductions h;
  initial h = new;
endmodule
