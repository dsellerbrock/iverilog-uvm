module main;
  int a[0:1][0:2];
  integer i;
  int selector_calls, rhs_calls;

  function automatic int pick_row;
    selector_calls = selector_calls + 1;
    pick_row = 1;
  endfunction

  function automatic int rhs_value;
    rhs_calls = rhs_calls + 1;
    rhs_value = 99;
  endfunction

  initial begin
    a[0] = '{1, 2, 3};
    a[1] = '{4, 5, 6};

    // The entire RHS is materialized before the selected row is written.
    i = 0;
    a[i] = '{a[i][2], a[i][1], a[i][0]};
    if (a[0][0] != 3 || a[0][1] != 2 || a[0][2] != 1)
      $fatal(1, "blocking dynamic row pattern lost alias snapshot");

    selector_calls = 0;
    a[pick_row()] = '{default:8};
    if (selector_calls != 1 || a[1][0] != 8 || a[1][2] != 8)
      $fatal(1, "blocking pattern selector was not evaluated once");

    // An invalid destination performs no write but still evaluates every RHS.
    rhs_calls = 0;
    i = 'x;
    a[i] = '{rhs_value(), rhs_value(), rhs_value()};
    if (rhs_calls != 3 || a[0][0] != 3 || a[0][2] != 1
        || a[1][0] != 8 || a[1][2] != 8)
      $fatal(1, "invalid blocking row pattern changed data or skipped RHS");
    $display("PASSED");
  end
endmodule
