virtual class pure_static_base;
  pure constraint fixed_value;
endclass

class pure_static_derived extends pure_static_base;
  static constraint fixed_value { 1; }
endclass

module test;
  pure_static_derived item;
endmodule
