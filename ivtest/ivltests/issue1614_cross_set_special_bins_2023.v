module issue1614_cross_set_special_bins;
  int a, b;

  covergroup cg(int lim);
    option.cross_retain_auto_bins = 0;
    ca: coverpoint a { bins x[] = {[0:3]}; }
    cb: coverpoint b { bins y[] = {[0:3]}; }
    cx: cross ca, cb {
      function CrossQueueType two();
        two.push_back(CrossValType'('{1, 1}));
        two.push_back(CrossValType'('{2, 2}));
      endfunction
      function CrossQueueType upto(int n);
        for (int i = 0; i < n; i++)
          upto.push_back(CrossValType'('{i, i}));
      endfunction
      bins one = two();
      ignore_bins ig = upto(1);
    }
  endgroup

  cg c = new(2);

  initial begin
    a = 1;
    b = 1;
    c.sample();
    if (c.cx.get_inst_coverage() != 100.0)
      $fatal(1, "cross set ignore_bins coverage=%f", c.cx.get_inst_coverage());
    $display("cx %.2f", c.cx.get_inst_coverage());
    $finish(0);
  end
endmodule
