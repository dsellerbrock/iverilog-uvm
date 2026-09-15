module test;
reg c1=0,c2=0,a=1,b=1,good=1;
int passes=0,failures=0; time verdict_time;
always #10 c1=~c1;
initial begin #35 c2=1; #1 c2=0; end
assert property (@(posedge c1) a ##[1:2] b |-> @(posedge c2) good)
 begin passes++; verdict_time=$time; end
 else begin failures++; verdict_time=$time; end
initial begin
 #11 begin a=0; $assertoff(0); end
 #20 b=0;
 #20;
 if(passes!=1 || failures!=0 || verdict_time!=50)
  $fatal(1,"source closure verdict p=%0d f=%0d at=%0t",passes,failures,verdict_time);
 $display("PASSED");$finish(0);
end
endmodule
