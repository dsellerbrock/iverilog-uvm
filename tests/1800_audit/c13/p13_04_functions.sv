module top;
  int pc, bg, nb, r1, r2;
  event ev;
  typedef struct { int a; int b; } s_t;

  function [15:0] myfunc1(input [7:0] x, y); myfunc1 = x * y - 1; endfunction
  function [15:0] myfunc2(input [7:0] x, y); return x * y - 1; endfunction
  function int ovr(); ovr = 5; return 9; endfunction
  function int empty_body(); endfunction
  function s_t mk(); mk.a = 3; mk.b = 4; endfunction
  function void myprint(int a); pc = a; endfunction
  function int cnt_static(); int k; k++; return k; endfunction
  function automatic int cnt_auto(); int k; k++; return k; endfunction
  function automatic int factorial(input [31:0] operand);
    if (operand >= 2) factorial = factorial(operand - 1) * operand; else factorial = 1;
  endfunction
  function integer clogb2(input [31:0] value);
    value = value - 1;
    for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1) value = value >> 1;
  endfunction
  localparam int AW = clogb2(421);
  function void spawn(); fork #5 bg = 7; join_none endfunction
  function void trig(); ->ev; endfunction
  function void nbf(); nb <= 3; endfunction

  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask

  initial begin
    s_t t;
    chk("13.4.1.assign_to_name", myfunc1(3, 4) == 11);
    chk("13.4.1.return_stmt", myfunc2(3, 4) == 11);
    chk("13.4.1.return_overrides_name", ovr() == 9);
    chk("13.4.empty_body_returns_implicit_var", empty_body() == 0);
    t = mk(); chk("13.4.1.struct_member_via_fn_name", t.a == 3 && t.b == 4);
    myprint(6); chk("13.4.1.void_call_stmt", pc == 6);
    r1 = cnt_static(); r2 = cnt_static(); chk("13.4.2.static_items_shared", r1 == 1 && r2 == 2);
    r1 = cnt_auto(); r2 = cnt_auto(); chk("13.4.2.automatic_items_fresh", r1 == 1 && r2 == 1);
    chk("13.4.2.recursive_factorial", factorial(7) == 5040);
    chk("13.4.3.constant_fn_clogb2", AW == 9);
    spawn(); chk("13.4.4.fork_join_none_returns_now", bg == 0);
    #6 chk("13.4.4.fork_join_none_body_runs", bg == 7);
    r1 = 0; fork begin @ev; r1 = 77; end join_none
    #0 trig(); #1 chk("13.4.4.event_trigger_in_fn", r1 == 77);
    nbf(); chk("13.4.4.nba_in_fn_deferred", nb == 0);
    #1 chk("13.4.4.nba_in_fn_lands", nb == 3);
    $display("DONE fails=%0d", fails);
  end
endmodule
