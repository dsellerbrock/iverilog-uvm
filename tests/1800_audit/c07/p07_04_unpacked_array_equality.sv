module test;
  int left[2];
  int right[2];
  bit equal_result;

  initial begin
    left = '{10, 20};
    right = '{10, 20};
    equal_result = left == right;
    if (!equal_result)
      $fatal(1, "equal unpacked arrays compared unequal");
    right[1] = 21;
    equal_result = left != right;
    if (!equal_result)
      $fatal(1, "different unpacked arrays compared equal");
    $display("PASS §7.4 array equality");
    $finish;
  end
endmodule
