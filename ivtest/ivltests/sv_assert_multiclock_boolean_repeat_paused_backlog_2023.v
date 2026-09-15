module test;
reg c1=0,c2=0,a=1,good=1;int p=0,f=0;time last;
always #10 c1=~c1;
initial begin #205 c2=1;#1 c2=0;#19 c2=1;#1 c2=0;end
assert property (@(posedge c1) a[*1:2] |-> @(posedge c2) good)
  begin p++;last=$time;end else begin f++;last=$time;end
initial begin
 #51 begin a=0;$assertoff(0);end
 #180;
 if(p!=3||f||last!=205)
   $fatal(1,"paused backlog p=%0d f=%0d last=%0t",p,f,last);
 $display("PASSED");$finish(0);
end
endmodule
