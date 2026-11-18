// Under -gcommercial-unsafe a circular ordering is a compile-time warning
// and retains its run-time failure.
class sv_constraint_order_unsafe_cycle;
  rand bit [1:0] a, b;
  constraint o { solve a before b; solve b before a; }
endclass

class sv_constraint_order_unsafe_legal;
  rand bit [1:0] a, b;
  constraint o { solve a before b; }
endclass

module sv_constraint_order_unsafe;
  sv_constraint_order_unsafe_cycle c = new;
  sv_constraint_order_unsafe_legal l = new;
  initial begin
    $display("circular rc=%0d", c.randomize());
    $display("legal rc=%0d", l.randomize());
  end
endmodule
