module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  int rj, cnt; string rs;
  function automatic int fun(int j = 1, string s = "no"); rj = j; rs = s; return j; endfunction
  function automatic bit is(int j, string s); return rj == j && rs == s; endfunction
  function void vnoargs(); cnt++; endfunction
  function void vdef(int a = 2); cnt += a; endfunction
  task tdefs(int a = 3); cnt += a; endtask
  class K; int n;
    function int m(); return 7; endfunction
    function void vm(); n++; endfunction
  endclass
  K k;
  initial begin
    void'(fun(.j(2), .s("yes"))); chk("13.5.4.fun(.j(2),.s(yes))", is(2, "yes"));
    void'(fun(.s("yes")));        chk("13.5.4.fun(.s(yes))", is(1, "yes"));
    void'(fun(, "yes"));          chk("13.5.4.fun(,yes)", is(1, "yes"));
    void'(fun(.j(2)));            chk("13.5.4.fun(.j(2))", is(2, "no"));
    void'(fun(.s("yes"), .j(2))); chk("13.5.4.fun(.s(yes),.j(2))", is(2, "yes"));
    void'(fun(.s(), .j()));       chk("13.5.4.fun(.s(),.j())", is(1, "no"));
    void'(fun(2));                chk("13.5.4.fun(2)", is(2, "no"));
    void'(fun());                 chk("13.5.4.fun()", is(1, "no"));
    void'(fun(2, .s("yes")));     chk("13.5.4.fun(2,.s(yes))", is(2, "yes"));
    cnt = 0; vnoargs;             chk("13.5.5.void_fn_no_args_no_parens", cnt == 1);
    vdef;                         chk("13.5.5.void_fn_all_defaults_no_parens", cnt == 3);
    tdefs;                        chk("13.5.5.task_all_defaults_no_parens", cnt == 6);
    k = new; k.vm;                chk("13.5.5.class_void_method_no_parens", k.n == 1);
    chk("13.5.5.class_nonvoid_method_no_parens", k.m == 7);
    $display("DONE fails=%0d", fails);
  end
endmodule
