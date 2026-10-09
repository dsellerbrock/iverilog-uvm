module test;
  int a, b;

  covergroup cg;
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
    b = 0;
    c.sample();
    if (c.cx.get_coverage() != 25.0)
      $fatal(1, "cross function set coverage=%f", c.cx.get_coverage());
    $display("PASSED");
    $finish(0);
  end
endmodule
