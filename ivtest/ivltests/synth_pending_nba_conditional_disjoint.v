module conditional_disjoint(input logic clk,rst,input logic a,b,input logic [3:0] x,y,
                            output logic [7:0] q);
  always_ff @(posedge clk) begin
    if (rst) q <= 0;
    else begin
      if (a) q[3:0] <= x;
      if (b) q[7:4] <= y;
    end
  end
endmodule
module tb_conditional_disjoint;
 logic clk=0,rst=1,a,b; logic [3:0] x,y; logic [7:0] q;
 conditional_disjoint dut(.*); always #5 clk=~clk;
 task step(input aa,bb,input [3:0] xx,yy,input [7:0] want);
   a=aa;b=bb;x=xx;y=yy;@(posedge clk);#1;if(q!==want)$fatal(1,"q=%h want=%h",q,want);
 endtask
 initial begin a=0;b=0;x=0;y=0;@(negedge clk);rst=0;
   step(1,0,4'ha,4'h0,8'h0a); step(0,1,0,4'hb,8'hba); step(1,1,4'hc,4'hd,8'hdc); $display("PASS");$finish(0);end
endmodule
