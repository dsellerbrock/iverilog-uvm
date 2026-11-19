module tb;
  bit root=0, clk1=0, clk2=0, a=1, b=1;
  int passes, failures;
  property p;
    (@(posedge clk1) a) and (@(posedge clk2) b);
  endproperty
  initial assert property (@(posedge root) 1'b1 |=> p)
    passes++; else failures++;
  initial begin #2 root=1; #1 root=0; #2 clk1=1; #3 clk2=1; #1;
    if (passes != 1 || failures != 0) $fatal(1,"passes=%0d failures=%0d",passes,failures);
    $display("PASS"); $finish;
  end
endmodule
