module sv_uarray_nested_function_return;

  typedef int pair_t[2:1];
  typedef pair_t pairs_t[2:1];

  function automatic pair_t make_pair(input int base);
    make_pair = '{base, base + 1};
  endfunction

  function automatic int make_scalar(input int value);
    make_scalar = value;
  endfunction

  pair_t direct;
  pairs_t nested;
  pairs_t defaulted;
  pairs_t scalar_defaulted;

  initial begin
    direct = make_pair(31);
    nested = '{make_pair(11), make_pair(21)};
    defaulted = '{default: make_pair(41)};
    scalar_defaulted = '{default: make_scalar(51)};

    if (direct[2] !== 31 || direct[1] !== 32
        || nested[2][2] !== 11 || nested[2][1] !== 12
        || nested[1][2] !== 21 || nested[1][1] !== 22
        || defaulted[2][2] !== 41 || defaulted[2][1] !== 42
        || defaulted[1][2] !== 41 || defaulted[1][1] !== 42
        || scalar_defaulted[2][2] !== 51 || scalar_defaulted[2][1] !== 51
        || scalar_defaulted[1][2] !== 51 || scalar_defaulted[1][1] !== 51)
      $fatal(1, "nested array-return assignment failed");

    $display("direct=%0d,%0d nested=%0d,%0d;%0d,%0d default=%0d,%0d;%0d,%0d scalar=%0d,%0d;%0d,%0d",
             direct[2], direct[1], nested[2][2], nested[2][1],
             nested[1][2], nested[1][1], defaulted[2][2], defaulted[2][1],
             defaulted[1][2], defaulted[1][1], scalar_defaulted[2][2],
             scalar_defaulted[2][1], scalar_defaulted[1][2],
             scalar_defaulted[1][1]);
    $display("PASSED");
    $finish(0);
  end

endmodule
