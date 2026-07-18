// IEEE 1800-2017 11.2.1: a constant expression cannot contain a
// hierarchical reference -- even one that resolves to a parameter of an
// instance (ivtest pr2792883). The fork's package-parameter exception
// (pkg::Y parsed as a hierarchical path) is now limited to parameters
// found in PACKAGE scopes.
module param_hier_ref;
  parameter WIDTH = dut.WIDTH;  // error: hierarchical ref in constant
  sub dut();
endmodule
module sub;
  parameter WIDTH = 8;
endmodule
