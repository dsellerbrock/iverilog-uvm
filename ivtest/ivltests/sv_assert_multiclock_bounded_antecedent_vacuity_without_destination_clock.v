module test;
reg c1=0,c2=0,a=0,b=1,good=1;
int passes=0,failures=0; time verdict_time;
always #10 c1=~c1;
assert property (@(posedge c1) a ##[1:2] b |-> @(posedge c2) good)
 begin passes++; verdict_time=$time; end
 else failures++;
initial begin
 #11 $assertoff(0);
 if(passes!=1 || failures!=0 || verdict_time!=10)
  $fatal(1,"vacuity waited for destination p=%0d f=%0d at=%0t",passes,failures,verdict_time);
 $display("PASSED");$finish(0);
end
endmodule
