module test; bit c1=0,c2=0,a=0,b=1,c=0; int p=0,f=0,pp=-1,fp=-1; always #10 c1=~c1; initial begin #5;forever #10 c2=~c2;end
sp:assert property(@(posedge c1) first_match(a##[1:2]b)##1@(posedge c2)c)begin p++;pp=$time;end else begin f++;fp=$time;end
initial begin #9 a=1;#22 a=0;$assertoff(0,sp);#9 c=1;#50;if(p!=1||f!=1||pp!=55||fp!=35)$fatal(1,"p%0d f%0d pp%0d fp%0d",p,f,pp,fp);$display("PASSED");$finish(0);end endmodule
