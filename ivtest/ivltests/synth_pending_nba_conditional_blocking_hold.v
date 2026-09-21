module conditional_blocking_hold(input logic clk,rst,a,b,input logic [7:0] d,e, output logic [7:0] q);
 always_ff @(posedge clk) begin
  if(rst) q<=0;
  else begin if(a) q=d; if(b) q<=e; end
 end
endmodule
module test;
 logic clk=0,rst=1,a=0,b=0;logic [7:0] d=0,e=0,q;
 conditional_blocking_hold dut(.*);always #5 clk=~clk;
 task step(input bit aa,bb,input logic [7:0] dd,ee,want);
  a=aa;b=bb;d=dd;e=ee;@(posedge clk);#1;
  if(q!==want)$fatal(1,"q=%h want=%h",q,want);
 endtask
 initial begin
  @(negedge clk);rst=0;
  step(0,0,8'h12,8'h34,0);
  step(1,0,8'h56,8'h78,8'h56);
  step(0,1,8'h9a,8'hbc,8'hbc);
  step(0,0,8'hde,8'hf0,8'hbc);
  step(1,1,8'h12,8'h34,8'h34);
  $display("PASS");$finish(0);
 end
endmodule
