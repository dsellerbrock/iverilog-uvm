package A; typedef struct {bit [7:0] opcode; bit [23:0] addr;} instruction_t; endpackage
package B; typedef enum bit {FALSE, TRUE} boolean_t; endpackage
module M import A::instruction_t, B::*; #(WIDTH = 32)
  (input [WIDTH-1:0] data, input instruction_t a, output [WIDTH-1:0] result, output boolean_t OK);
  assign result = data;
  assign OK = TRUE;
endmodule
module top;
  wire [31:0] r;
  B::boolean_t ok;
  A::instruction_t ia;
  M m(32'hCAFE, ia, r, ok);
  initial #1 $display("P6 %h %0d", r, ok);
endmodule
