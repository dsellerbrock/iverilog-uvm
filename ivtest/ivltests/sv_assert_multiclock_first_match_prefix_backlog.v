module test;bit c1=0,c2=0,a=0,b=1,c=1;int p=0,f=0,last=-1;always #10 c1=~c1;
sp:assert property(@(posedge c1)first_match(a##[1:2]b)##1@(posedge c2)c)begin p++;last=$time;end else f++;
initial begin #9 a=1;#22 a=0;$assertoff(0,sp);#69 c2=1;#1 c2=0;#20;if(p!=2||f||last!=100)$fatal(1,"p%0d f%0d last%0d",p,f,last);$display("PASSED");$finish(0);end endmodule
