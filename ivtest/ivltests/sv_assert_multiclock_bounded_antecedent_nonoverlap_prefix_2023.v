module test;
reg c1=0,c2=0,a=1,b=1,prefix=1,good=1;int p=0,f=0;time verdict_time;
always #10 c1=~c1;
initial begin #55 c2=1;#1 c2=0;#19 c2=1;#1 c2=0;end
assert property (@(posedge c1)
      a ##[1:2] b |=> prefix ##1 @(posedge c2) good)
 begin p++;verdict_time=$time;end
 else begin f++;verdict_time=$time;end
initial begin
 #11 $assertoff(0);
 #49 prefix=0;
 #16;
 if(p!=0||f!=1||verdict_time!=70)
   $fatal(1,"nonoverlap prefix p=%0d f=%0d at=%0t",p,f,verdict_time);
 $display("PASSED");$finish(0);
end
endmodule
