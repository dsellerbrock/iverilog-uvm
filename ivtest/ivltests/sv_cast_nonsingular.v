module sv_cast_nonsingular;
  int arr[2];
  int scalar;
  int result;
  int calls;

  function int scalar_source();
    calls++;
    return 1;
  endfunction

  initial begin
    arr = '{7, 8};
    result = $cast(arr, scalar_source());
    $display("function result=%0d arr=%0d,%0d calls=%0d",
             result, arr[0], arr[1], calls);

    $cast(arr, scalar_source());
    $display("task arr=%0d,%0d calls=%0d", arr[0], arr[1], calls);

    result = $cast(scalar, 9);
    $display("singular result=%0d scalar=%0d", result, scalar);
    scalar = 0;
    $cast(scalar, 11);
    $display("singular task scalar=%0d", scalar);
    $display("PASSED");
    $finish;
  end
endmodule
