module conditional_blocking_read(input logic clk,rst,a,input logic d,
 output logic [7:0] q,seen);
 always_ff @(posedge clk) begin
  if(rst) begin q<=8'ha0;seen<=0;end
  else begin if(a) q[0]=d; seen<=q;end
 end
endmodule
module test;
 logic clk=0,rst=1,a=0,d=0;logic[7:0] q,seen;
 conditional_blocking_read dut(.*);always #5 clk=~clk;
 task step(input bit aa,dd,input logic[7:0] want);
  a=aa;d=dd;@(posedge clk);#1;
  if(q!==want || seen!==want)$fatal(1,"q=%h seen=%h want=%h",q,seen,want);
 endtask
 initial begin @(negedge clk);rst=0;
  step(1,1,8'ha1);step(0,0,8'ha1);step(1,0,8'ha0);
  $display("PASS");$finish(0);
 end
endmodule
