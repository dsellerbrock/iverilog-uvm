module sv_procedural_cycle_delay_zero;
  logic clk = 0;
  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking
  initial begin
    ##(0) $display("zero cycle delay accepted");
    #1 $finish;
  end
endmodule
