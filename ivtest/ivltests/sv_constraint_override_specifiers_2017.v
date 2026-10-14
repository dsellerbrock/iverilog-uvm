class constraint_override_2017_bad;
  rand bit value;
  constraint :initial selected { value == 0; }
endclass

module test;
  constraint_override_2017_bad item;
  initial item = new;
endmodule
