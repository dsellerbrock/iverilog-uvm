`timescale 1ns/1ps
module p21v;
 reg clk=0; reg [3:0] v=4'b0010; real r=1.5; event ev; wire w=1'b1; integer cnt=0; reg [3:0] hidden=4'h5;
 sub u1();
 initial begin
  $dumpfile("p21v.vcd");
  #10 $dumpvars(0, p21v);
  #5 v=4'bx10z; r=2.25; ->ev;
  #5 $dumpoff; #5 v=4'b1111; #5 $dumpon;
  #5 v=4'b0001; #5 $dumpall; #5 $dumpflush; #5 $finish;
 end
 always #1 clk=~clk;
endmodule
module sub; reg [1:0] s=2'b11; initial #20 s=2'b00; endmodule
