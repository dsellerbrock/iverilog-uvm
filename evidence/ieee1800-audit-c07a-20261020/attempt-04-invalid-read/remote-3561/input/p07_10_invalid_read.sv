module p07_10_invalid_read;
  int q[$] = '{10, 20};
  int empty[$];
  bit bq[$] = '{1};
  int iv;
  bit bv;

  initial begin
    iv = q[2];
    $display("OOB_INT %0d", $isunknown(iv));
    if (!$isunknown(iv)) $fatal(1, "out-of-range int queue read must be X");

    iv = empty[0];
    $display("EMPTY_INT %0d", $isunknown(iv));
    if (!$isunknown(iv)) $fatal(1, "empty int queue read must be X");

    bv = bq[1];
    $display("OOB_BIT %0d", bv);
    if (bv !== 1'b0) $fatal(1, "out-of-range bit queue read must be 0");

    $display("PASS");
  end
endmodule
