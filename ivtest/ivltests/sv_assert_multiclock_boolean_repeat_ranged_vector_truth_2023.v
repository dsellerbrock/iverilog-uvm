module test;
reg c1=0,c2=0;reg[7:0]a=8'h80;reg good=1;int p=0,f=0;
initial begin #10 c1=1;#1 c1=0;#19 c1=1;#1 c1=0;#19 c1=1;#1 c1=0;end
initial begin #35 c2=1;#1 c2=0;#19 c2=1;#1 c2=0;end
assert property(@(posedge c1)a[*2:3]|->@(posedge c2)good)p++;else f++;
initial begin #11 $assertoff(0);#50;if(p!=1||f)$fatal(1,"p%0d f%0d",p,f);$display("PASSED");$finish(0);end
endmodule
