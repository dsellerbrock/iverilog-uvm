module sv_uarray_nested_function_return_shape_fail;

  typedef int pair_t[2:1];
  typedef int triple_t[3:1];
  typedef pair_t pairs_t[2:1];

  function automatic triple_t make_triple(input int base);
    make_triple = '{base, base + 1, base + 2};
  endfunction

  pairs_t nested;

  initial nested = '{make_triple(11), make_triple(21)};

endmodule
