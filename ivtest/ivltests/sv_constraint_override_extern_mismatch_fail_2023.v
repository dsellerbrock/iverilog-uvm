class constraint_override_extern_base;
  rand bit value;
endclass

class constraint_override_extern_bad extends constraint_override_extern_base;
  extern constraint :initial selected;
endclass

constraint constraint_override_extern_bad::selected { value == 1; }

module test;
  constraint_override_extern_bad item;
  initial item = new;
endmodule
