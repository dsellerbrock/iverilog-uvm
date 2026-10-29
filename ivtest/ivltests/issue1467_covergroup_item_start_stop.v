module top;
  covergroup controls with function sample(bit a, bit b);
    ca: coverpoint a { bins zero = {0}; bins one = {1}; }
    cb: coverpoint b { bins zero = {0}; bins one = {1}; }
    cx: cross ca, cb;
  endgroup

  controls c;
  initial begin
    c = new;
    c.sample(0, 0);
    c.ca.stop();
    c.sample(1, 1);
    if (c.ca.get_inst_coverage() != 50.0
        || c.cx.get_inst_coverage() != 50.0)
      $fatal(1, "stopped items changed: cp=%0.1f cross=%0.1f",
             c.ca.get_inst_coverage(), c.cx.get_inst_coverage());

    c.cx.stop();
    c.sample(0, 1);
    if (c.ca.get_inst_coverage() != 50.0
        || c.cx.get_inst_coverage() != 50.0)
      $fatal(1, "stopped cross changed: cp=%0.1f cross=%0.1f",
             c.ca.get_inst_coverage(), c.cx.get_inst_coverage());

    c.ca.start();
    c.sample(1, 0);
    if (c.ca.get_inst_coverage() != 100.0
        || c.cx.get_inst_coverage() != 50.0)
      $fatal(1, "coverpoint control was not independent: cp=%0.1f cross=%0.1f",
             c.ca.get_inst_coverage(), c.cx.get_inst_coverage());

    c.cx.start();
    c.sample(0, 1);
    if (c.ca.get_inst_coverage() != 100.0
        || c.cx.get_inst_coverage() != 75.0)
      $fatal(1, "cross control was not independent: cp=%0.1f cross=%0.1f",
             c.ca.get_inst_coverage(), c.cx.get_inst_coverage());
    $display("PASSED");
  end
endmodule
