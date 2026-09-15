module test;
reg c1=0,c2=0,a=1,b=1,good=1;int p=0,f=0;time last_fail;
always #10 c1=~c1;
initial begin #35 c2=1;#1 c2=0;#19 c2=1;#1 c2=0;#19 c2=1;#1 c2=0;end
assert property (@(posedge c1) a ##[1:2] b |-> @(posedge c2) good)
 p++; else begin f++;last_fail=$time;end
initial begin
 #31 begin a=0;$assertoff(0);end
 #23 good=0;
 #27;
 if(p!=0||f!=2||last_fail!=55)
   $fatal(1,"overlapping parents p=%0d f=%0d at=%0t",p,f,last_fail);
 $display("PASSED");$finish(0);
end
endmodule
