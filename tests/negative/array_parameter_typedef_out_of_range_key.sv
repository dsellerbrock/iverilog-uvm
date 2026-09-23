// An indexed array-pattern key must be within the declared dimension.
package array_parameter_typedef_out_of_range_key_pkg;
  typedef bit [7:0] bytes_t [1:4];
  localparam bytes_t Invalid = '{1:8'h11, 5:8'h55, default:8'h00};
endpackage
module main;
  import array_parameter_typedef_out_of_range_key_pkg::*;
  initial $display("%h", Invalid[1]);
endmodule
