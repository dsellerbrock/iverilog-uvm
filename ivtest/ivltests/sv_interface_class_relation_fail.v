module test;
  class concrete_base;
  endclass

  class invalid_implementation implements concrete_base;
  endclass

  interface class invalid_extension extends concrete_base;
  endclass
endmodule
