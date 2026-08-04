// IEEE 1800-2017 16.9.2 and 26.3: a cycle-delay bound may be a
// constant expression whose local parameter depends on a wildcard-imported
// package parameter. OpenTitan uses this shape in its alert-handler FPV.
package delay_cfg_pkg;
  parameter int ImportedExponent = 2;
endpackage

interface delay_check_if
  import delay_cfg_pkg::*;
(
  input logic clk,
  input logic req,
  input logic ack
);
  localparam int WindowHi = 2 ** ImportedExponent;
  int failures = 0;

  bounded: assert property (@(posedge clk) req |-> ##[1:WindowHi] ack)
    else failures++;
endinterface

module main;
  logic clk = 0;
  logic req = 1;
  logic ack = 0;
  delay_check_if check_if(clk, req, ack);

  always #5 clk = ~clk;

  initial begin
    // req is sampled at t=5. ack is sampled at t=45, exactly WindowHi
    // cycles later. A misfolded upper bound either rejects the source or
    // expires this obligation too early.
    #6 req = 0;
    #33 ack = 1;
    #12 ack = 0;
    #10;
    if (check_if.failures != 0)
      $display("FAILED -- wildcard-imported parameter delay expired early (%0d)",
               check_if.failures);
    else
      $display("PASSED");
    $finish(0);
  end
endmodule
