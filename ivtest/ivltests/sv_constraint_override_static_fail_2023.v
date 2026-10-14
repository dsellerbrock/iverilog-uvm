class constraint_override_static_bad;
  static constraint :initial selected { 1; }
endclass

module test;
  constraint_override_static_bad item;
  initial item = new;
endmodule
