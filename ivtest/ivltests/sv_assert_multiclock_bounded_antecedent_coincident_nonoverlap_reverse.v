module test;
reg c1=0,c2=0,a=1,b=1,good=1; int p=0,f=0;time at;
always #10 c2=~c2;
always #10 c1=~c1;
assert property (@(posedge c1) a ##[0:2] b |=> @(posedge c2) good) p++; else begin f++;at=$time;end
initial begin #11; a=0;$assertoff(0);#58;good=0;#2;if(p!=0||f!=1||at!=70)$fatal(1,"verdict p=%0d f=%0d at=%0t",p,f,at);$display("PASSED");$finish(0);end
endmodule
