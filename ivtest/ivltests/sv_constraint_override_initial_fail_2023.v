class constraint_override_initial_base;
  rand bit value;
  constraint selected { value == 0; }
endclass

class constraint_override_initial_bad extends constraint_override_initial_base;
  constraint :initial selected { value == 1; }
endclass

module test;
  constraint_override_initial_bad item;
  initial item = new;
endmodule
