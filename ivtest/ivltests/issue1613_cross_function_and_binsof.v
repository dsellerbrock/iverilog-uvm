module test;
  int a, b;
  covergroup cg;
`ifdef ISSUE1613_2023
    option.cross_retain_auto_bins = 0;
`endif
    ca: coverpoint a { bins x[] = {[0:3]}; }
    cb: coverpoint b { bins y[] = {[0:3]}; }
    cx: cross ca, cb {
      function CrossQueueType two(int n);
        two.push_back('{1, 1});
        if (n > 1) two.push_back('{2, 2});
      endfunction
      bins one = two(2) && binsof(ca) intersect {1};
    }
  endgroup
  cg c = new;
  initial begin
    a = 1; b = 1; c.sample();
`ifdef ISSUE1613_2023
    if (c.cx.get_coverage() != 100.0)
`else
    if (c.cx.get_coverage() != 6.25)
`endif
      $fatal(1, "cross function && binsof coverage=%f", c.cx.get_coverage());
    $display("PASSED");
    $finish(0);
  end
endmodule
