module test;bit c1=0,c2=0,a=0,x=1,b=1,c=1,d=0;int p=0,f=0,pt=-1;always #10 c2=~c2;always #10 c1=~c1;
sp:assert property(@(posedge c1)a##[1:2]x##0@(posedge c2)(b##1 c)[*1:2]##1 d)begin p++;pt=$time;end else f++;
initial begin #9 a=1;#2 a=0;$assertoff(0,sp);#78 d=1;#2 d=0;#40;if(p!=1||f||pt!=90)$fatal(1,"p%0d f%0d pt%0d",p,f,pt);$display("PASSED");$finish(0);end endmodule
