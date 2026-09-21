module case_no_match(input logic clk,rst,input logic [1:0] sel,input logic [7:0] d,
                     output logic [7:0] q, z);
  always_ff @(posedge clk) begin
    if (rst) begin q <= 0; z <= 0; end
    else begin
      q <= d;
      z <= d;
      case (sel)
        0: q <= d + 1;
        1: q <= d + 2;
      endcase
      casez (sel)
        2'b0?: z <= d + 3;
      endcase
    end
  end
endmodule
module tb_case_no_match;
  logic clk=0,rst=1; logic [1:0] sel=0; logic [7:0] d=0,q,z;
  case_no_match dut(.*); always #5 clk=~clk;
  task step(input [1:0] s,input [7:0] data, wantq, wantz);
    sel=s;d=data;@(posedge clk);#1;
    if(q!==wantq || z!==wantz) $fatal(1,"case q=%h z=%h",q,z);
  endtask
  initial begin
    @(negedge clk);rst=0;
    step(0,8'h10,8'h11,8'h13);
    step(1,8'h20,8'h22,8'h23);
    step(2,8'h30,8'h30,8'h30);
    $display("PASS");$finish(0);
  end
endmodule
