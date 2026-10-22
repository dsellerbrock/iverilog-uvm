checker p17_03_checker(input logic clk, input logic sig);
  a_signal_high: assert property (@(posedge clk) sig);
endchecker

module p17_03_procedural_checker_instance;
  logic clk = 0;
  logic sig = 0;

  initial begin
    p17_03_checker instance(clk, sig);
    #1 sig = 1;
    #1 clk = 1;
    #1 clk = 0;
    $display("PASS procedural checker instance");
    $finish;
  end
endmodule
