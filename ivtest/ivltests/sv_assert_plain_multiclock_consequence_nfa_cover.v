module test;bit c1=0,c2=0,a=0,b=1,c=1,d=0;int n=0,ct=-1;always #10 c1=~c1;always #10 c2=~c2;
cp:cover property(@(posedge c1)a##1@(posedge c2)(b ##1 c)[*1:2]##1 d)begin n++;ct=$time;end
initial begin #9 a=1;#2 a=0;$assertoff(0,cp);#98 d=1;#2;if(n!=1||ct!=110)$fatal(1,"n%0d ct%0d",n,ct);$display("PASSED");$finish(0);end endmodule
