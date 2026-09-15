module test;bit c1=0,c2=0,a=0,b=1,c=1,d=0;int p=0,f=0,last=-1;always #10 c1=~c1;always #10 c2=~c2;
sp:assert property(@(posedge c1)a##1@(posedge c2)(b ##1 c)[*1:2]##1 d)begin p++;last=$time;end else f++;
initial begin #9 a=1;#22 a=0;$assertoff(0,sp);#78 d=1;#2 d=0;#18 d=1;#2;if(p!=2||f||last!=130)$fatal(1,"p%0d f%0d last%0d",p,f,last);$display("PASSED");$finish(0);end endmodule
