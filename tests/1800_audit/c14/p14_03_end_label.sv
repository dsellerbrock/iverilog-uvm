module test;
  wire clk = 0;
  wire d = 0;
  clocking cb @(posedge clk);
    input d;
  endclocking : cb

  initial begin
    $display("PASSED");
    $finish(0);
  end
endmodule
