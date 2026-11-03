module top;
  int d[];
  int q[$];

  initial begin
    if ($bits(d) != 0)
      $fatal(1, "empty dynamic array: expected 0 bits, got %0d", $bits(d));

    d = new[3];
    q = {1, 2, 3};
    if ($bits(d) != 96 || $bits(q) != 96 || d.size() != 3)
      $fatal(1, "three elements: d=%0d q=%0d size=%0d",
             $bits(d), $bits(q), d.size());

    d = new[5];
    if ($bits(d) != 160)
      $fatal(1, "five elements: expected 160 bits, got %0d", $bits(d));

    d = new[0];
    if ($bits(d) != 0)
      $fatal(1, "empty after resize: expected 0 bits, got %0d", $bits(d));

    $display("PASSED");
  end
endmodule
