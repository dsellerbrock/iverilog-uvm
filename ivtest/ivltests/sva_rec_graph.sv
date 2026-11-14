// IEEE 1800-2023 16.12.17 / F.7: the legal recursive declarations of the
// standard are accepted by the restriction checks and identified as
// recursive, including a cycle closed by a forward reference and F.7's
// cycle through an actual argument (p1 -> p3 -> p1). Recursive properties
// still have no engine (#1187), so each gets one sorry, in declaration
// order, and assertions that instantiate them are dropped without hanging.
module sva_rec_graph;
  logic clk = 0, a = 1, b = 1, s1 = 0, s2 = 0;
  logic phase1_prop = 1, phase2_prop = 1;
  property prop_always(p);
    p and (1'b1 |=> prop_always(p));
  endproperty
  property p1s(s, p);
    s |=> prop_always(p);
  endproperty
  property prop_weak_until(p, q);
    q or (p and (1'b1 |=> prop_weak_until(p, q)));
  endproperty
  property check_phase1;
    s1 |-> (phase1_prop and (1'b1 |=> check_phase2));
  endproperty
  a0: assert property (@(posedge clk) check_phase1);
  property check_phase2;
    s2 |-> (phase2_prop and (1'b1 |=> check_phase1));
  endproperty
  property fibonacci1 (local input int x, y, n, int fib_sig);
    (n > 0) |-> ((fib_sig == x) and (1'b1 |=> fibonacci1(y, x + y, n - 1, fib_sig)));
  endproperty
  property f1(v);
    v |=> f2(f3());
  endproperty
  property f2(v);
    a or (1'b1 |=> v);
  endproperty
  property f3;
    f1(a && b);
  endproperty
  a1: assert property (@(posedge clk) prop_always(a));
  a2: assert property (@(posedge clk) a |=> prop_always(b));
  a3: assert property (@(posedge clk) p1s(a, b));
  a4: assert property (@(posedge clk) prop_weak_until(a, b));
endmodule
