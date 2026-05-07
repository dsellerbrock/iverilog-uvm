// p58: G35 — array reverse() method
// Dynamic arrays support reverse(); tests the method chain concept.
module top;
  initial begin
    automatic int arr[] = '{5, 3, 1, 4, 2};
    arr.reverse();
    if (arr[0] == 2 && arr[1] == 4 && arr[4] == 5)
      $display("PASS: darray reverse p58");
    else
      $display("FAIL: arr[0]=%0d arr[4]=%0d", arr[0], arr[4]);
    $finish;
  end
endmodule
