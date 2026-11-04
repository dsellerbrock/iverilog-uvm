module tb;
  int a, b;

  covergroup cg(int lim);
`ifdef ISSUE1616_NO_AUTO_BINS
    option.cross_retain_auto_bins = 0;
`endif
    ca: coverpoint a { bins x[] = {[0:3]}; }
    cb: coverpoint b { bins y[] = {[0:3]}; }
    cx: cross ca, cb {
      function CrossQueueType two();
        two.push_back('{1, 1});
        two.push_back('{2, 2});
      endfunction

      function CrossQueueType upto(int n);
        for (int i = 0; i < n; i++) upto.push_back('{i, i});
      endfunction

      bins one = upto(lim);
    }
  endgroup

  cg c = new(2);
  cg d = new(1);

  initial begin
    a = 1;
    b = 1;
    c.sample();
    d.sample();

`ifdef ISSUE1616_NO_AUTO_BINS
    if (c.cx.get_inst_coverage() != 100.0
        || d.cx.get_inst_coverage() != 0.0)
      $fatal(1, "instance bins c=%0.2f d=%0.2f",
             c.cx.get_inst_coverage(), d.cx.get_inst_coverage());
`else
    if (c.cx.get_inst_coverage() < 6.66
        || c.cx.get_inst_coverage() > 6.68
        || d.cx.get_inst_coverage() < 6.24
        || d.cx.get_inst_coverage() > 6.26)
      $fatal(1, "instance bins c=%0.2f d=%0.2f",
             c.cx.get_inst_coverage(), d.cx.get_inst_coverage());
`endif

    $display("PASSED");
  end
endmodule
