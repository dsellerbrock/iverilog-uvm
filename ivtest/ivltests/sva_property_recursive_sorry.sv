// IEEE 1800-2023 16.12.17 recursive properties are legal, but are not
// supported yet: each recursive declaration gets a sorry instead of an
// unresolved-name error. Self recursion, the standard's weak-until form,
// and mutual recursion.
module sva_property_recursive_sorry;
  logic clk = 0, a = 1, b = 0, s1 = 0, s2 = 0;
  always #5 clk = ~clk;
  property prop_always(p);
    p and (1'b1 |=> prop_always(p));
  endproperty
  property prop_weak_until(p, q);
    q or (p and (1'b1 |=> prop_weak_until(p, q)));
  endproperty
  property check_phase1;
    s1 |-> (a and (1'b1 |=> check_phase2));
  endproperty
  property check_phase2;
    s2 |-> (b and (1'b1 |=> check_phase1));
  endproperty
  a1: assert property (@(posedge clk) prop_always(a));
  a2: assert property (@(posedge clk) prop_weak_until(a, b));
  a3: assert property (@(posedge clk) check_phase1);
endmodule
