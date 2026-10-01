module test; bit c1=0,c2=0,a=0,b=1,c=1; int p=0,f=0,pt=-1; always #10 c2=~c2; always #10 c1=~c1;
sp:assert property(@(posedge c1) first_match(a##[1:2]b)##0@(posedge c2)c)begin p++;pt=$time;end else f++;
initial begin #9 a=1;#2 a=0;$assertoff(0,sp);#60;if(p!=1||f||pt!=30)$fatal(1,"p%0d f%0d pt%0d",p,f,pt);$display("PASSED");$finish(0);end endmodule
