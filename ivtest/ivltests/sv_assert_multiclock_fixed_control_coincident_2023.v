module test;reg c1=0,c2=0,a=1,good=1;int p=0,f=0;time at;
initial begin #10;c1=1;c2=1;#1;c1=0;c2=0;#19;c1=1;c2=1;#1;c1=0;c2=0;end
assert property(@(posedge c1)a|->@(posedge c2)good)begin p++;at=$time;end else f++;
initial begin #11;$assertoff(0);#20;if(p!=1||f||at!=10)$fatal(1,"p%0d f%0d at%0t",p,f,at);$display("PASSED");$finish(0);end endmodule
