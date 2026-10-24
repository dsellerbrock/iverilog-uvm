module p20_12_actl;
  logic clk = 0; always #5 clk = ~clk;
  int cf = 0, imf = 0, ap = 0;
  a1: assert property (@(posedge clk) 1'b0) else cf++;
  always @(posedge clk) a2: assert (1'b0) else imf++;
  a3: assert property (@(posedge clk) 1'b1) ap++;
  initial begin
    $assertoff(0, a1, a2);  #20 $display("C1 %0d %0d", cf, imf);
    $asserton(0, a1, a2);   #20 $display("C2 %0d %0d", cf, imf);
    $assertcontrol(9, 15, 7, 0, a1, a2); #20 $display("C3 %0d %0d", cf, imf);
    $assertcontrol(8, 15, 7, 0, a1, a2); #20 $display("C4 %0d %0d", cf, imf);
    $assertkill(0, a1, a2); #20 $display("C5 %0d %0d %0d", cf, imf, ap > 0);
    $finish;
  end
endmodule
