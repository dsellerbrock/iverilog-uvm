module test;
  int a[3][][5];

  initial begin
    a[2] = new[4];
    $display("dimensions=%0d size1=%0d size3=%0d", $unpacked_dimensions(a),
             $size(a, 1), $size(a, 3));
    $display("selected_size=%0d empty_selected_size=%0d",
             $size(a[2], 1), $size(a[1], 1));
    if ($unpacked_dimensions(a) != 3 || $size(a, 1) != 3
        || $size(a, 3) != 5 || $size(a[2], 1) != 4
        || $size(a[1], 1) != 0)
      $fatal(1, "nested array query mismatch");
    $display("PASS");
  end
endmodule
