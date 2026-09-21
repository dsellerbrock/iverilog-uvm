module loop_capture(input logic clk,rst,input logic [1:0] limit,input logic [3:0] base,
                    output logic [15:0] q);
 integer i;
 always_ff @(posedge clk) begin
   if (rst) q <= 0;
   else for (i=0; i<4; i=i+1)
     if (i <= limit) q[i*4 +: 4] <= base + i;
 end
endmodule
module tb_loop_capture;
 logic clk=0,rst=1; logic [1:0] limit; logic [3:0] base; logic [15:0] q;
 loop_capture dut(.*); always #5 clk=~clk;
 initial begin limit=2;base=4'h5;@(negedge clk);rst=0;@(posedge clk);#1;
   if(q!==16'h0765)$fatal(1,"q=%h",q); $display("PASS");$finish(0);end
endmodule
