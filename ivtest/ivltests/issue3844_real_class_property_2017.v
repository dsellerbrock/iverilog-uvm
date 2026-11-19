class real_property_inner;
  real r;
endclass

class real_property_outer;
  real r;
  real words[8:9];
  real_property_inner inner;

  function new;
    inner = new;
  endfunction
endclass

module issue3844_real_class_property;
  real_property_outer c = new;
  logic [95:0] idx;
  int count;

  initial begin
    count = $sscanf("1.5", "%f", c.r);
    if (count != 1 || c.r != 1.5)
      $fatal(1, "scalar real property scan failed");

    c.words[8] = 0.5;
    c.words[9] = -0.5;
    idx = 9;
    count = $sscanf("2.25 -3.75", "%f %f", c.inner.r, c.words[idx]);
    if (count != 2 || c.inner.r != 2.25
        || c.words[8] != 0.5 || c.words[9] != -3.75)
      $fatal(1, "nested real property or fixed-array word scan failed");
    if ($sformatf("%.2f", c.words[idx]) != "-3.75")
      $fatal(1, "fixed-array word read through VPI failed");

    count = $sscanf("mismatch", "%f", c.r);
    if (count != 0 || c.r != 1.5)
      $fatal(1, "failed match modified the scalar real property");

    idx = 8;
    count = $value$plusargs("REAL=%f", c.words[idx]);
    if (count == 0 || c.words[8] != 4.125 || c.words[9] != -3.75)
      $fatal(1, "real plusarg did not update the selected word");
    count = $value$plusargs("MISSING=%f", c.r);
    if (count != 0 || c.r != 1.5)
      $fatal(1, "missing plusarg modified the scalar real property");

    // The oversized indices have the same low bits as valid indices.
    idx = 96'h1_00000000_00000008;
    count = $sscanf("5.5", "%f", c.words[idx]);
    idx = 96'h1_00000009;
    count = $sscanf("5.5", "%f", c.words[idx]);
    idx = 96'b1x00;
    count = $sscanf("5.5", "%f", c.words[idx]);
    idx = 96'b100z;
    count = $sscanf("5.5", "%f", c.words[idx]);
    idx = 10;
    count = $sscanf("5.5", "%f", c.words[idx]);
    if (c.words[8] != 4.125 || c.words[9] != -3.75)
      $fatal(1, "invalid index modified a fixed-array word");
    if ($sformatf("%.2f", c.words[idx]) != "0.00")
      $fatal(1, "invalid fixed-array word read did not return 0.0");

    $display("PASSED");
  end
endmodule
