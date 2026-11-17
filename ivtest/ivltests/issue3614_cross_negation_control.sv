module tb;
  bit a, b;
  covergroup cg;
    ca: coverpoint a { bins zero = {0}; bins one = {1}; }
    cb: coverpoint b { bins zero = {0}; bins one = {1}; }
    cx: cross ca, cb {
      ignore_bins other = !binsof(ca) intersect {0};
    }
  endgroup
  cg c = new;
  initial begin
    a = 0; b = 0; c.sample();
    if (c.cx.get_inst_coverage() != 50.0) $fatal(1, "wrong selected bins");
    a = 1; b = 1; c.sample();
    if (c.cx.get_inst_coverage() != 50.0) $fatal(1, "ignored bin counted");
    a = 0; b = 1; c.sample();
    if (c.cx.get_inst_coverage() != 100.0) $fatal(1, "wrong coverage");
    $display("PASSED");
  end
endmodule
