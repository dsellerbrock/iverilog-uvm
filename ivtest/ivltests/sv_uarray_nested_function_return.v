module sv_uarray_nested_function_return;

  typedef int pair_t[2:1];
  typedef pair_t pairs_t[2:1];

  function automatic pair_t make_pair(input int base);
    make_pair = '{base, base + 1};
  endfunction

  pair_t direct;
  pairs_t nested;

  initial begin
    direct = make_pair(31);
    nested = '{make_pair(11), make_pair(21)};

    if (direct[2] !== 31 || direct[1] !== 32
        || nested[2][2] !== 11 || nested[2][1] !== 12
        || nested[1][2] !== 21 || nested[1][1] !== 22)
      $fatal(1, "nested array-return assignment failed");

    $display("direct=%0d,%0d nested=%0d,%0d;%0d,%0d",
             direct[2], direct[1], nested[2][2], nested[2][1],
             nested[1][2], nested[1][1]);
    $display("PASSED");
    $finish(0);
  end

endmodule
