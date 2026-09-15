module test;reg c1=0,c2=0,a=1,good=1;int p=0,f=0;time at;always #10 c1=~c1;initial begin #55;c2=1;#1;c2=0;end
assert property(@(posedge c1)a|=>@(posedge c2)good)begin p++;at=$time;end else f++;
initial begin #1;$assertkill(0);#20;$asserton(0);#10;$assertoff(0);#25;if(p!=1||f||at!=55)$fatal(1,"p%0d f%0d at%0t",p,f,at);$display("PASSED");$finish(0);end endmodule
