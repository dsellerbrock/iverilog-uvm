module issue1437_cross_function_scope;
  int a, b;
  covergroup cg;
    ca: coverpoint a { bins zero = {0}; }
    cb: coverpoint b { bins zero = {0}; }
    cx: cross ca, cb {
      function CrossQueueType choose_one();
        choose_one.push_back(CrossValType'('{0,0}));
      endfunction
      bins selected = choose_one();
    }
  endgroup
  cg cov = new;
  initial $display("%0d", choose_one().size());
endmodule
