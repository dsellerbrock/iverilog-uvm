// p61: G36 — array sort() method
// Dynamic arrays support sort() in-place.
module top;
  initial begin
    automatic int arr[] = '{5, 3, 1, 4, 2};
    arr.sort();
    if (arr[0] == 1 && arr[1] == 2 && arr[4] == 5)
      $display("PASS: darray sort p61");
    else
      $display("FAIL: arr=%0d %0d %0d %0d %0d", arr[0],arr[1],arr[2],arr[3],arr[4]);
    $finish;
  end
endmodule
