module test;
  int a, b;

  covergroup cg_bad_arity;
    ca: coverpoint a { bins vals[] = {[0:1]}; }
    cb: coverpoint b { bins vals[] = {[0:1]}; }
    cx: cross ca, cb {
      function CrossQueueType choose_arity();
        choose_arity.push_back(CrossValType'('{0}));
      endfunction
      bins malformed = choose_arity();
    }
  endgroup

  covergroup cg_bad_type;
    ca: coverpoint a { bins vals[] = {[0:1]}; }
    cb: coverpoint b { bins vals[] = {[0:1]}; }
    cx: cross ca, cb {
      function CrossQueueType choose_type();
        choose_type.push_back(1);
      endfunction
      bins malformed = choose_type();
    }
  endgroup

  covergroup cg_bad_expression;
    ca: coverpoint a { bins vals[] = {[0:1]}; }
    cb: coverpoint b { bins vals[] = {[0:1]}; }
    cx: cross ca, cb {
      function int choose_expr();
        choose_expr = 0;
      endfunction
      bins malformed = choose_expr();
    }
  endgroup
endmodule
