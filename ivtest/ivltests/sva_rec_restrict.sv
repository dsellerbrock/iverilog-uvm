// IEEE 1800-2023 16.12.17 / F.7: the four restrictions on recursive
// property declarations, with the standard's illegal examples that parse.
module sva_rec_restrict;
  logic clk = 0, a = 1, b = 0;
  int fib_sig;
  property prop_always(p);
    p and (1'b1 |=> prop_always(p));
  endproperty
  property uses_always(p);
    1'b1 |=> prop_always(p);
  endproperty
  // Restriction 1: `not' and the strong operators cannot be applied to a
  // property expression from which a recursive property is reachable.
  // The first is applied before its recursive target is declared.
  property illegal_recursion_2(p);
    p and (1'b1 |=> not illegal_recursion_2(p));
  endproperty
  property strong_over_recursion(p);
    s_eventually prop_always(p);
  endproperty
  property strong_over_dependent(p);
    s_nexttime uses_always(p);
  endproperty
  a1: assert property (@(posedge clk) not prop_always(a));
  // Restriction 2: no disable iff in a recursive declaration. legal_3 is
  // legal: it is not itself recursive.
  property illegal_recursion_3(p);
    disable iff (b)
    p and (1'b1 |=> illegal_recursion_3(p));
  endproperty
  property legal_3(p);
    disable iff (b) prop_always(p);
  endproperty
  // Restriction 3: every cycle advances time; q3's ##2 is a legal advance.
  property illegal_recursion_4(p);
    p and (1'b1 |-> illegal_recursion_4(p));
  endproperty
  property q1;
    a |-> q2;
  endproperty
  property q2;
    a and q1;
  endproperty
  property q3;
    a ##2 a |-> q3;
  endproperty
  // Restriction 4: actuals of a recursive instance.
  property fibonacci2 (int x, y, n, fib_sig);
    (n > 0)
    |->
    (
      (fib_sig == x)
      and
      (1'b1 |=> fibonacci2(y, x + y, n - 1, fib_sig))
    );
  endproperty
endmodule
