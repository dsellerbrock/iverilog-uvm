class constraint_override_extends_bad;
  rand bit value;
  constraint :extends selected { value == 1; }
endclass

module test;
  constraint_override_extends_bad item;
  initial item = new;
endmodule
