// G35: reverse() on fixed-size unpacked array
module g35_uarray_reverse_test;
  initial begin
    int arr[4];
    arr[0] = 10; arr[1] = 20; arr[2] = 30; arr[3] = 40;
    arr.reverse();
    if (arr[0] != 40 || arr[1] != 30 || arr[2] != 20 || arr[3] != 10) begin
      $display("FAIL: reverse got %0d %0d %0d %0d", arr[0], arr[1], arr[2], arr[3]);
      $finish;
    end
    $display("PASS");
  end
endmodule
