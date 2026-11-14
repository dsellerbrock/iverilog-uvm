// Under -gcommercial-unsafe the 18.5.9 ordering errors are warnings: the
// non-rand operand is dropped from the ordering, and a circular ordering
// keeps its run-time failure.
class sv_constraint_order_unsafe_nonrand;
  int a;
  rand int b;
  constraint o { solve a before b; b inside {[0:3]}; }
endclass

class sv_constraint_order_unsafe_cycle;
  rand bit [1:0] a, b;
  constraint o { solve a before b; solve b before a; }
endclass

class sv_constraint_order_unsafe_legal;
  rand bit [1:0] a, b;
  constraint o { solve a before b; }
endclass

module sv_constraint_order_unsafe;
  sv_constraint_order_unsafe_nonrand n = new;
  sv_constraint_order_unsafe_cycle c = new;
  sv_constraint_order_unsafe_legal l = new;
  initial begin
    $display("nonrand rc=%0d b_ok=%0d", n.randomize(), n.b inside {[0:3]});
    $display("circular rc=%0d", c.randomize());
    $display("legal rc=%0d", l.randomize());
  end
endmodule
