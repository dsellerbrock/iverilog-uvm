module test;
reg c1=0,c2=0,a=1,good=1;int p=0,f=0;time last;
always #10 c1=~c1;always #10 c2=~c2;
assert property (@(posedge c1) a[*0:2] |=> @(posedge c2) good)
 begin p++;last=$time;end else begin f++;last=$time;end
initial begin #31 begin a=0;$assertoff(0);end #30;
 if(p!=2||f||last!=50)$fatal(1,"p%0d f%0d at%0t",p,f,last);
 $display("PASSED");$finish(0);end
endmodule
