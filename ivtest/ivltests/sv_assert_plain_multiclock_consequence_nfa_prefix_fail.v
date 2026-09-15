module test;bit c1=0,c2=0,a=0,x=0,b=1,c=1,d=1;int p=0,f=0,ft=-1;always #10 c1=~c1;always #10 c2=~c2;
sp:assert property(@(posedge c1)a##1 x##1@(posedge c2)(b ##1 c)[*1:2]##1 d)begin p++;end else begin f++;ft=$time;end
initial begin #9 a=1;#2 a=0;$assertoff(0,sp);#20;if(p||f!=1||ft!=30)$fatal(1,"p%0d f%0d ft%0d",p,f,ft);$display("PASSED");$finish(0);end endmodule
