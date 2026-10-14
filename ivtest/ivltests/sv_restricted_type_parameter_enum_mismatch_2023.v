class enum_holder #(type enum T);
endclass

module test;
  enum_holder#(int) invalid;
endmodule
