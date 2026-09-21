module main;
  int a[2][3];
  int calls;

  function automatic int select_outer(input int value);
    calls++;
    return value;
  endfunction

  initial begin
    int visits;
    foreach (a[select_outer(0)][j]) visits++;
    if (calls != 1 || visits != 3)
      $fatal(1, "first foreach calls=%0d visits=%0d", calls, visits);

    foreach (a[select_outer(1)][j]) visits++;
    if (calls != 2 || visits != 6)
      $fatal(1, "second foreach calls=%0d visits=%0d", calls, visits);

    // 7.4.6: an invalid unpacked-array read yields the type's default
    // value. The selected-away index does not remove the dimensions of
    // that value, so the remaining dimension still has three elements.
    foreach (a[select_outer(2)][j]) visits++;
    if (calls != 3 || visits != 9)
      $fatal(1, "boundary foreach calls=%0d visits=%0d", calls, visits);
    $display("PASSED");
  end
endmodule
