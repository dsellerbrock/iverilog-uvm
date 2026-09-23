// A keyed array assignment pattern may specify each declared index only once.
package array_parameter_typedef_duplicate_key_pkg;
  typedef bit [7:0] bytes_t [0:1];
  localparam bytes_t Invalid = '{0:8'h11, 0:8'h22, default:8'h00};
endpackage
module main;
  import array_parameter_typedef_duplicate_key_pkg::*;
  initial $display("%h", Invalid[0]);
endmodule
