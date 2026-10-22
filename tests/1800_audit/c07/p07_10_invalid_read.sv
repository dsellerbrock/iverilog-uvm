module p07_10_invalid_read;
  logic q[$] = '{10, 20};
  logic empty[$];
  int iq[$] = '{10, 20};
  bit bq[$] = '{1};
  logic lv;
  int iv;
  bit bv;

  initial begin
    lv = q[2];
    $display("OOB_LOGIC %0d", $isunknown(lv));
    if (!$isunknown(lv)) $fatal(1, "out-of-range logic queue read must be X");

    lv = empty[0];
    $display("EMPTY_LOGIC %0d", $isunknown(lv));
    if (!$isunknown(lv)) $fatal(1, "empty logic queue read must be X");

    iv = iq[2];
    $display("OOB_INT %0d", iv);
    if (iv !== 0) $fatal(1, "out-of-range int queue read must be 0");

    bv = bq[1];
    $display("OOB_BIT %0d", bv);
    if (bv !== 1'b0) $fatal(1, "out-of-range bit queue read must be 0");

    $display("PASS");
  end
endmodule
