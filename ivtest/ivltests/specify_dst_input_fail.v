// IEEE 1800 30.3: a module path destination shall be an output or inout
// port. The errors are reported and the compiler exits normally.
`timescale 1ns/1ns
module specify_dst_input_fail_m(input a, input b, output y, output z);
  assign y = a;
  assign z = a;
  specify
    (a => b) = 1;
    (z => b) = 1;
  endspecify
endmodule

module specify_dst_input_fail;
  reg a, b;
  wire y, z;
  specify_dst_input_fail_m u(a, b, y, z);
endmodule
