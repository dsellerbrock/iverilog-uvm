module test;
 bit c1=0,c2=0,a=0,b=1,c=1,d=0; int covers=0,ct=-1;
 always #10 c1=~c1; always #10 c2=~c2;
 cp: cover property(@(posedge c1) a |-> @(posedge c2)
      (b ##1 c)[*1:2] ##1 d) begin covers++;ct=$time;end
 initial begin #9 a=1;#2 a=0;$assertoff(0,cp);#78 d=1;#2;
  if(covers!=1||ct!=90)begin $display("FAILED covers%0d ct%0d",covers,ct);$finish(1);end
  $display("PASSED");$finish(0);end
endmodule
