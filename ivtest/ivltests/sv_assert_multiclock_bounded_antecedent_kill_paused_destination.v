module test;
reg c1=0,c2=0,a=1,b=1,good=1;int p=0,f=0;time at;
always #10 c1=~c1;
initial begin #95;c2=1;#1;c2=0;#19;c2=1;#1;c2=0;end
assert property (@(posedge c1) a ##[1:2] b |-> @(posedge c2) good)
 begin p++;at=$time;end else begin f++;at=$time;end
initial begin
 #11;$assertoff(0);#29;$assertkill(0);#20;$asserton(0);#11;$assertoff(0);
 #50;if(p!=1||f!=0||at!=115)$fatal(1,"kill/restart p=%0d f=%0d at=%0t",p,f,at);
 $display("PASSED");$finish(0);
end
endmodule
