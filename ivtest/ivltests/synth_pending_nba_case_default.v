module case_default(input logic clk, rst, input logic [1:0] sel, input logic [7:0] d,
                    output logic [7:0] q);
  always_ff @(posedge clk) begin
    if (rst) q <= '0;
    else case (sel)
      2'd0: q <= d + 8'd1;
      2'd1: q <= d + 8'd2;
      default: q <= d + 8'd3;
    endcase
  end
endmodule
module tb_case_default;
 logic clk=0,rst=1; logic [1:0] sel; logic [7:0] d,q;
 case_default dut(.*); always #5 clk=~clk;
 task tick(input [1:0] s,input [7:0] v,input [7:0] want);
   sel=s; d=v; @(posedge clk); #1; if(q!==want) $fatal(1,"case q=%h want=%h",q,want);
 endtask
 initial begin sel=2; d=0; repeat(1) @(negedge clk); rst=0;
   tick(0,8'h10,8'h11); tick(1,8'h20,8'h22); tick(2,8'h30,8'h33); $display("PASS"); $finish(0); end
endmodule
