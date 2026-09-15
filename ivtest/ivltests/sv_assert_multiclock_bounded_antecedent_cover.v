module test;
reg c1=0,c2=0,a=1,b=1,good=1;
int covers=0;
always #10 c1=~c1;
initial begin #35 c2=1;#1 c2=0;#19 c2=1;#1 c2=0;end
cover property (@(posedge c1) a ##[1:2] b |-> @(posedge c2) good) covers++;
initial begin #11 begin a=0;$assertoff(0);end #60;if(covers!=1)$fatal(1,"cover parent count=%0d",covers);$display("PASSED");$finish(0);end
endmodule
