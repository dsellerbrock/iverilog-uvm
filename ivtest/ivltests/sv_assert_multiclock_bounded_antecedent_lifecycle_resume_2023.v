module test;
reg c1=0,c2=0,a=1,b=1,good=1;
int late_passes=0,failures=0;
always #1 c1=~c1;
assert property (@(posedge c1) a ##[1:2] b |-> @(posedge c2) good)
 begin if($time>=2002) late_passes++; end
 else failures++;
initial begin
 #2 a=0;
 #1998 $assertoff(0);
 #2 c2=1;#1 c2=0;
 #4;
 if(late_passes!=1 || failures!=0)
   $fatal(1,"retained child verdict p=%0d f=%0d",late_passes,failures);
 if(_ivl_sva0_mcrkind0.num()>8)
   $fatal(1,"record stream not reclaimed: %0d",_ivl_sva0_mcrkind0.num());
 $display("PASSED");$finish(0);
end
endmodule
