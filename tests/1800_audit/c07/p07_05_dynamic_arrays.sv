module test;
  int dynamic_a[];
  int dynamic_copy[];

  initial begin
    if (dynamic_a.size() != 0)
      $fatal(1, "unallocated dynamic array size should be zero");

    dynamic_a = new[4];
    if (dynamic_a.size() != 4)
      $fatal(1, "new[4] produced size %0d", dynamic_a.size());
    for (int i = 0; i < 4; i++) dynamic_a[i] = (i + 1) * 100;

    dynamic_copy = new[6](dynamic_a);
    if (dynamic_copy.size() != 6 || dynamic_copy[0] != 100
        || dynamic_copy[3] != 400 || dynamic_copy[4] != 0)
      $fatal(1, "dynamic array new[size](source) copy mismatch");

    dynamic_a.delete();
    if (dynamic_a.size() != 0)
      $fatal(1, "delete() did not empty the dynamic array");

    $display("PASS §7.5 dynamic array allocation, copy, size, and delete");
    $finish;
  end
endmodule
