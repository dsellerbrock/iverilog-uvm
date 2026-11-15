// IEEE 1800-2023 18.5.9: "Only random variables are allowed, that is, they
// shall be rand." and "There shall be no circular dependencies in the
// ordering". Both are compile errors (IEEE_RULINGS.md, #832).
class sv_constraint_order_fail_nonrand;
  int a;
  rand int b;
  constraint o { solve a before b; b inside {[0:3]}; }
endclass

class sv_constraint_order_fail_cycle;
  rand bit [1:0] a, b;
  constraint o { solve a before b; solve b before a; }
endclass

class sv_constraint_order_fail_base;
  rand bit [1:0] a, b, c;
  constraint o1 { solve a before b; }
  constraint o2 { solve b before c; }
endclass

// The cycle a -> b -> c -> a closes through the inherited blocks.
class sv_constraint_order_fail_derived extends sv_constraint_order_fail_base;
  constraint o3 { solve c before a; }
endclass

// o1 is overridden, so b -> a replaces a -> b: no cycle.
class sv_constraint_order_fail_override extends sv_constraint_order_fail_base;
  constraint o1 { solve b before a; }
endclass

module sv_constraint_order_fail;
  sv_constraint_order_fail_nonrand n = new;
  sv_constraint_order_fail_cycle c = new;
  sv_constraint_order_fail_derived d = new;
  sv_constraint_order_fail_override o = new;
endmodule
