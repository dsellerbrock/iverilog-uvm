module test;
reg c1=0,c2=0,a=1,b=1,good=1,rst=0;
int passes=0,failures=0;
always #10 c1=~c1;
initial begin #35 c2=1;#1 c2=0;#19 c2=1;#1 c2=0;#39 c2=1;#1 c2=0;#19 c2=1;#1 c2=0;end
assert property (@(posedge c1) disable iff(rst) a ##[1:2] b |-> @(posedge c2) good)
 passes++; else failures++;
initial begin
 #11 begin a=0;$assertoff(0);end #29 rst=1;#2 rst=0;
 #18 begin a=1;$asserton(0);end #11 begin a=0;$assertoff(0);end // fresh parent at c1=70
 #60;if(passes!=1||failures!=0)$fatal(1,"disable p=%0d f=%0d",passes,failures);
 $display("PASSED");$finish(0);
end
endmodule
