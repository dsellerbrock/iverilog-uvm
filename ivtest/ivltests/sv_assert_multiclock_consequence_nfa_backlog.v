module test;
 bit c1=0,c2=0,a=0,b=1,c=1,d=0; int p=0,f=0,last=-1;
 always #10 c1=~c1;
 ap: assert property(@(posedge c1) a |-> @(posedge c2)
      (b##1 c)[*1:2]##1 d) begin p++;last=$time;end else f++;
 initial begin
  #9 a=1; #22 a=0;$assertoff(0,ap); // parents at 10 and 30; c2 paused
  #69 c2=1;#1 c2=0; #19 c2=1;#1 c2=0; #19 c2=1;#1 c2=0;
  #19 c2=1;#1 c2=0; #18 d=1;#1 c2=1;#1 c2=0; #1;
  if(p!=2||f!=0||last!=180) begin $display("FAILED p%0d f%0d last%0d",p,f,last);$finish(1);end
  $display("PASSED");$finish(0);end
endmodule
