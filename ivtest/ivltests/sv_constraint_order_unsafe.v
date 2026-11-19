// Under -gcommercial-unsafe a circular ordering is a compile-time warning
// and the circular edges are omitted.
class sv_constraint_order_unsafe_cycle;
  rand bit [1:0] a, b;
  constraint o { solve a before b; solve b before a; a != b; }
endclass

class sv_constraint_order_unsafe_legal;
  rand bit [1:0] a, b;
  constraint o { solve a before b; }
endclass

module sv_constraint_order_unsafe;
  sv_constraint_order_unsafe_cycle c = new;
  sv_constraint_order_unsafe_legal l = new;
  initial begin
    if (!c.randomize() || c.a == c.b)
      $fatal(1, "circular order lost its value constraint");
    if (!l.randomize()) $fatal(1, "legal order failed");
    $display("PASSED");
  end
endmodule
