module test;reg c1=0,c2=0,a=1,good=1;int ap=0,bp=0,cp=0,af=0,bf=0;always #10 c1=~c1;initial begin #15;c2=1;#1;c2=0;#19;c2=1;#1;c2=0;end
A:assert property(@(posedge c1)a|->@(posedge c2)good)ap++;else af++;
B:assert property(@(posedge c1)a|->@(posedge c2)good)bp++;else bf++;
C:cover property(@(posedge c1)a|->@(posedge c2)good)cp++;
initial begin #1;$assertoff(0,A);$assertoff(0,C);#35;if(ap||af||cp||bp!=2||bf)$fatal(1,"a%0d/%0d b%0d/%0d c%0d",ap,af,bp,bf,cp);$display("PASSED");$finish(0);end endmodule
