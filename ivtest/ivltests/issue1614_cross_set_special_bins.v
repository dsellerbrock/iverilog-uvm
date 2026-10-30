module issue1614_cross_set_special_bins;
  int a, b;

  covergroup cg(int lim);
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
      function CrossQueueType bad_pair();
        bad_pair.push_back(CrossValType'('{3, 3}));
      endfunction
      bins one = two();
      ignore_bins ig = upto(1);
      illegal_bins bad = bad_pair();
    }
  endgroup

  cg c = new(2);

  initial begin
    a = 0;
    b = 0;
    c.sample();
    if (c.cx.get_inst_coverage() != 0.0)
      $fatal(1, "ignore_bins set expression counted a tuple");

    a = 1;
    b = 1;
    c.sample();
    if (c.cx.get_inst_coverage() <= 0.0)
      $fatal(1, "normal cross set bin was not counted");

    $display("PASSED");
    $finish(0);
  end
endmodule
