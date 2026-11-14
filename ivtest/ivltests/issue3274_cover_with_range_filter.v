// Issue #3274 (IEEE 1800-2023 19.5.1.1): a 'with' filter over a wide
// coverpoint domain is evaluated as value ranges, not by enumerating
// every value: comparisons with a constant, inside, and !, &&, ||.
module top;
  int value;
  covergroup cg;
    cp: coverpoint value {
      bins low = cp with (item < 2 && item > -3);            // -2 .. 1
      bins neg[4] = cp with (item < 0);                      // 2**31 values, 4 bins
      bins few[] = cp with (item >= 10 && item <= 12);       // 10, 11, 12
      bins big = cp with (!(item <= 1000) || item == -7);    // > 1000, or -7
      bins mid = {[0:100]} with (item inside {[20:30]} && item != 25);
    }
  endgroup
  cg c;
  initial begin
    c = new;
    value = 1;    c.sample();   // low
    value = -5;   c.sample();   // neg[3]
    value = 11;   c.sample();   // few[11]
    value = 5000; c.sample();   // big
    value = 25;   c.sample();   // nothing: mid leaves 25 out
    // 10 bins (1 + 4 + 3 + 1 + 1), 4 of them hit.
    if (c.cp.get_inst_coverage() > 39.99 && c.cp.get_inst_coverage() < 40.01)
      $display("PASSED");
    else
      $display("FAILED: coverage %0.3f, want 40.000", c.cp.get_inst_coverage());
  end
endmodule
