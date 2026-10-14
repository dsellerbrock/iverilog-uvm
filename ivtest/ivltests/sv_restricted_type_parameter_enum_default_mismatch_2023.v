class enum_holder #(type enum T = int);
endclass

module test;
  enum_holder#() invalid;
endmodule
