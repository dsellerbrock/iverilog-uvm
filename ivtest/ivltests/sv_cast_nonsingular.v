module sv_cast_nonsingular;
  int arr[2];
  int result;

  initial begin
    arr = '{7, 8};
    result = $cast(arr, 1);
    if (result !== 0) $fatal(1, "incompatible function cast succeeded");
    if (arr[0] != 7 || arr[1] != 8)
      $fatal(1, "failed function cast changed destination");

    $cast(arr, 1);
    if (arr[0] != 7 || arr[1] != 8)
      $fatal(1, "failed task cast changed destination");

    $display("PASS non-singular $cast");
    $finish;
  end
endmodule
