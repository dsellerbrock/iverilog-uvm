class constraint_override_mutually_exclusive_bad;
  rand bit value;
  constraint :initial :extends selected { value == 1; }
endclass

module test;
  constraint_override_mutually_exclusive_bad item;
  initial item = new;
endmodule
