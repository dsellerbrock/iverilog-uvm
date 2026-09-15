module test;
reg c1=0,c2=0,a=1,b=1,good=1;int p=0,f=0;
always #1 c1=~c1;
initial begin #1000;c2=1;#1;c2=0;end
assert property (@(posedge c1) a ##[1:3] b |-> @(posedge c2) good) p++;else f++;
initial begin #256;$assertoff(0);#746;
 if(p!=128||f!=0)$fatal(1,"queued parent count p=%0d f=%0d",p,f);
 $display("PASSED");$finish(0);end
endmodule
