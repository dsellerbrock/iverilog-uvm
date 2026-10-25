// IEEE 1800-2017/2023 14.5: a clocking output declaration assignment
// must be legal as the connection to a module output port.
module sv_clocking_output_nonlvalue_fail;
  logic clk, a, b;

  clocking cb @(posedge clk);
    output out = a + b;
  endclocking

  initial begin
    clk = 0;
    a = 0;
    b = 1;
    #1 $finish;
  end
endmodule
