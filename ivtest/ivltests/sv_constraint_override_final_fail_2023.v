class constraint_override_final_base;
  rand bit value;
  constraint :final selected { value == 0; }
endclass

class constraint_override_final_bad extends constraint_override_final_base;
  constraint selected { value == 1; }
endclass

module test;
  constraint_override_final_bad item;
  initial item = new;
endmodule
