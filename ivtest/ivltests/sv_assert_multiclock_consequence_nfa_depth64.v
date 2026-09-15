module test;
 bit c1=0,c2=0,a=0,b=1,c=1,d=1;int p=0,f=0,pt=-1;
 always #10 c1=~c1;always #10 c2=~c2;
 ap: assert property(@(posedge c1)a|->@(posedge c2)b##[1:2]c##61 d)
  begin p++;pt=$time;end else f++;
 initial begin #9 a=1;#2 a=0;$assertoff(0,ap);#1240;
  if(p!=1||f!=0||pt!=1250)begin $display("FAILED p%0d f%0d pt%0d",p,f,pt);$finish(1);end
  $display("PASSED");$finish(0);end
endmodule
