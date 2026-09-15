module test;
reg c1=0,c2=0,a=1,prefix=1,good=1;int p=0,f=0;time last;
always #10 c1=~c1;
initial begin #50 c2=1;#1 c2=0;#19 c2=1;#1 c2=0;end
assert property (@(posedge c1)
  a[*0:2] |=> prefix ##1 @(posedge c2) good)
  begin p++;last=$time;end else begin f++;last=$time;end
initial begin
 #31 begin a=0;$assertoff(0);end
 #45;
 if(p!=2||f||last!=70)
   $fatal(1,"mixed prefix p=%0d f=%0d last=%0t",p,f,last);
 $display("PASSED");$finish(0);
end
endmodule
