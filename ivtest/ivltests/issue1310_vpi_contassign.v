// Issue #1310: continuous assignments are VPI objects under their module
// (IEEE 1800-2023 37.47): vpiLhs, vpiRhs, vpiNetDeclAssign, strengths,
// value, and value-change callbacks on the assignment.
module top;
  logic src;
  logic [3:0] a, b;
  wire out;
  wire [3:0] sum = a + b;
  assign (weak0, weak1) out = src;
  initial begin
    $caprobe;
    src = 0;
    a = 1;
    b = 2;
    #1 src = 1;
    #1 a = 3;
    #1 $cadone;
  end
endmodule
