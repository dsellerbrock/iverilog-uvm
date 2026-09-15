module test;
reg c1=0,c2=0,a=1,b=1,good=0;
int passes=0,failures=0; time verdict_time;
always #10 c1=~c1;
initial begin #35 c2=1; #1 c2=0; end
assert property (@(posedge c1) a ##[1:2] b |-> @(posedge c2) good)
 begin passes++; verdict_time=$time; end
 else begin failures++; verdict_time=$time; end
initial begin
 #11 begin a=0; $assertoff(0); end
 #25;
 if(passes!=0 || failures!=1 || verdict_time!=35)
  $fatal(1,"early child verdict p=%0d f=%0d at=%0t",passes,failures,verdict_time);
 #30;
 if(failures!=1) $fatal(1,"duplicate parent failure");
 $display("PASSED");$finish(0);
end
endmodule
