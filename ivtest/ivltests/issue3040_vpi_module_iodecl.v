// IEEE 1800-2023 37.5, 37.13: a module's I/O declarations iterate
// (vpiIODecl), with their direction and the port's net as vpiExpr.
module issue3040_child(input logic a, output logic b, inout wire [3:0] c);
  assign b = a;
endmodule

module top;
  logic a = 1;
  wire b;
  wire [3:0] c;
  issue3040_child u(a, b, c);
  task t(input int x); endtask
  initial begin
    #1 $probe;
    $display("PASSED");
  end
endmodule
