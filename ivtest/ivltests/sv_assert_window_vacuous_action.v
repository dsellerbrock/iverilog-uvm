// IEEE 1800-2017/2023 16.12.7, 16.14.1, 20.12.
module check #(parameter HI=3)(input clk,a,b,c,d,dis);
 integer fp=0,ff=0,op=0,ofail=0,ap=0,af=0;
 sequence Pair(x,y); x ##2 y; endsequence
 flat: assert property (@(posedge clk) disable iff(dis) a ##2 b |-> ##[0:HI] 1'b1) fp++; else ff++;
 ors: assert property (@(posedge clk) disable iff(dis) Pair(a,b) or Pair(c,d) |-> ##[0:HI] 1'b1) op++; else ofail++;
 ands: assert property (@(posedge clk) disable iff(dis) Pair(a,b) and Pair(c,d) |-> ##[0:HI] 1'b1) ap++; else af++;
endmodule
module test;
 reg clk=0,a=0,b=0,c=0,d=0,dis=0;
 check dut(clk,a,b,c,d,dis);
 task tick; #5 clk=1; #1 clk=0; endtask
 task counts(input integer f,o,n);
  if(dut.fp!=f || dut.op!=o || dut.ap!=n || dut.ff || dut.ofail || dut.af)
   $fatal(1,"counts=%0d/%0d/%0d expected=%0d/%0d/%0d",dut.fp,dut.op,dut.ap,f,o,n);
 endtask
 initial begin
  tick(); counts(1,1,1);
  a=1; tick(); counts(1,1,2);
  a=0;c=1;tick();counts(2,1,3);
  c=0;b=1;tick();counts(4,3,4);
  b=0;tick();counts(5,5,5);
  a=1;tick();counts(5,5,6);
  $assertoff(0,dut);a=0;
  tick();counts(5,5,6);
  tick();counts(6,6,6);
  $asserton(0,dut);
  a=1;c=1;tick();counts(6,6,6);
  // An asynchronous disable pulse cancels all older branches.
  dis=1;#1;dis=0;a=0;c=0;
  tick();counts(7,7,7);tick();counts(8,8,8);
  a=1;c=1;tick();counts(8,8,8);
  $assertkill(0,dut);$asserton(0,dut);a=0;c=0;
  tick();counts(9,9,9);tick();counts(10,10,10);
  $display("PASSED");
 end
endmodule
