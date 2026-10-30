typedef logic logic_array_t[1:0];
checker input_array(input logic a[1:0] = '{default:1'b0}); endchecker
checker output_array(output logic a[1:0] = '{default:1'b0}); endchecker
checker input_array_alias(input logic_array_t a = '{default:1'b0}); endchecker
checker output_array_alias(output logic_array_t a = '{default:1'b0}); endchecker
module top; endmodule
