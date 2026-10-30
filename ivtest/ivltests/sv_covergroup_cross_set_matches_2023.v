module tb;
  int a, b;
  covergroup cg(int lim);
    ca: coverpoint a { bins x[] = {[0:3]}; }
    cb: coverpoint b { bins y[] = {[0:3]}; }
    cx: cross ca, cb {
      function CrossQueueType two();
        two.push_back('{1, 1});
        two.push_back('{2, 2});
      endfunction
      bins one = two() matches 1;
    }
  endgroup
  cg c = new(2);
  initial begin
    a = 1;
    b = 1;
    c.sample();
    if (c.cx.get_inst_coverage() <= 0.0)
      $fatal(1, "cross set matches coverage=%f", c.cx.get_inst_coverage());
    $display("PASSED");
    $finish(0);
  end
endmodule
