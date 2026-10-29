package issue1385_property_scope_pkg;
  logic package_clk;
  property package_property; @(posedge package_clk) 1'b1; endproperty
endpackage

logic compilation_unit_clk;
property compilation_unit_property;
  @(posedge compilation_unit_clk) 1'b1;
endproperty

module issue1385_property_scope;
endmodule
