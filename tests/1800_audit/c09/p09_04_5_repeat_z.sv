module top; logic [3:0] zc = 4'bz; bit clk = 0; int x; time t0;
  always #5 clk = ~clk;
  initial begin #1000 $display("INFO repeat_z_timeout: still waiting after 1000 units"); $finish; end
  initial begin
    t0 = $time; x = repeat (zc) @(posedge clk) 6;
    $display("INFO repeat_z elapsed=%0d x=%0d", $time - t0, x); #1 $finish;
  end
endmodule
