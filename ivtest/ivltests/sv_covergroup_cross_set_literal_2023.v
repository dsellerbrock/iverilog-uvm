module test;
  int a, b;

  covergroup cg;
    option.cross_retain_auto_bins = 0;
    ca: coverpoint a { bins x[] = {[0:3]}; }
    cb: coverpoint b { bins y[] = {[0:3]}; }
    cx: cross ca, cb {
      bins one = '{'{1, 1}, '{2, 2}};
    }
  endgroup

  cg c = new;

  initial begin
    a = 1;
    b = 1;
    c.sample();
    if (c.cx.get_inst_coverage() != 100.0)
      $fatal(1, "literal cross set coverage=%f", c.cx.get_inst_coverage());
    $display("PASSED");
    $finish(0);
  end
endmodule
