virtual class base_c;
  pure constraint required_constraint;
endclass

virtual class intermediate_c extends base_c;
endclass

class concrete_c extends intermediate_c;
endclass

module test;
  concrete_c item;
endmodule
