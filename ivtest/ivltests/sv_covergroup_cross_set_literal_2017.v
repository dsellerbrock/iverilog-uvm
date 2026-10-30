module test;
  int a, b;

  covergroup cg;
    ca: coverpoint a { bins x[] = {[0:3]}; }
    cb: coverpoint b { bins y[] = {[0:3]}; }
    cx: cross ca, cb {
      bins one = '{'{1, 1}, '{2, 2}};
    }
  endgroup

  cg c = new;

  initial begin
    a = 0;
    b = 0;
    c.sample();
    a = 1;
    b = 1;
    c.sample();
    if (c.cx.get_inst_coverage() < 13.332 || c.cx.get_inst_coverage() > 13.334)
      $fatal(1, "literal cross set coverage=%f", c.cx.get_inst_coverage());
    $display("PASSED");
    $finish(0);
  end
endmodule
