module test;
  int a, b;

  covergroup cg;
    option.cross_retain_auto_bins = 0;
    ca: coverpoint a { bins vals[] = {[0:1]}; }
    cb: coverpoint b { bins vals[] = {[0:1]}; }
    cx: cross ca, cb {
      function CrossQueueType choose_one();
        choose_one.push_back(CrossValType'('{0,0}));
      endfunction
      bins only00 = choose_one();
    }
  endgroup

  cg c = new;

  initial begin
    a = 0;
    b = 1;
    c.sample();
    if (c.cx.get_coverage() != 0.0)
      $fatal(1, "unselected tuple coverage=%f", c.cx.get_coverage());
    a = 0;
    b = 0;
    c.sample();
    if (c.cx.get_coverage() != 100.0)
      $fatal(1, "selected tuple coverage=%f", c.cx.get_coverage());
    $display("PASSED");
    $finish(0);
  end
endmodule
