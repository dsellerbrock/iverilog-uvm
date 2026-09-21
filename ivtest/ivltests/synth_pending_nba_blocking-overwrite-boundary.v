module dut(input clk, sel, inc, input [7:0] d, output [7:0] q0,q1);
 reg [7:0] a[2];
 integer i;
 always @(posedge clk) begin
  i=0;
  if(sel) i=1;
  if(inc) i=i+1;
  a[i]<=d;
 end
 assign q0=a[0]; assign q1=a[1];
endmodule
module test;
 reg clk=0,sel=0,inc=0; reg[7:0]d=8'h12;
 wire[7:0]q0,q1;
 dut u(clk,sel,inc,d,q0,q1);
 task tick; #1 clk=1; #1 clk=0; endtask
 initial begin
 tick(); if(q0!==8'h12 || q1!==8'hxx) $fatal(1,"initial selector q0=%h q1=%h",q0,q1);
 sel=1; d=8'h34; tick(); if(q0!==8'h12 || q1!==8'h34) $fatal(1,"conditional overwrite");
 sel=0; inc=1; d=8'h56; tick(); if(q0!==8'h12 || q1!==8'h56) $fatal(1,"self increment");
 sel=1; d=8'h78; tick(); if(q0!==8'h12 || q1!==8'h56) $fatal(1,"OOB no-write");
 $display("PASSED");$finish(0);
 end
endmodule
