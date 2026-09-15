module test;
reg c1=0,c2=0,a=1,b=1,good=1;
int passes=0,failures=0;
always #10 c1=~c1;
initial begin #5; forever #10 c2=~c2; end
assert property (@(posedge c1) a ##[1:2] b |-> @(posedge c2) good)
  passes++; else failures++;
initial begin
  #11 begin a=0; $assertoff(0); end
  #34 good=0;
  #16 good=1;
  #30;
  if (passes!=0 || failures!=1)
    $fatal(1,"parent verdict passes=%0d failures=%0d",passes,failures);
  $display("PASSED");$finish(0);
end
endmodule
