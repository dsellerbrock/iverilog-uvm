module top; bit c1=0,c2=0,a=0,b=0; always #5 c1=~c1; always #7 c2=~c2;
  assert property (@(posedge c1) a ##1 @(posedge c2) b);
  initial begin #40 $display("PASS"); $finish(0); end
endmodule
