module partial_blocking(input logic clk,rst,input logic [3:0] nib,
                        output logic [7:0] q, output logic [7:0] seen);
  always_ff @(posedge clk) begin
    if (rst) begin q <= 8'h00; seen <= 0; end
    else begin
      q[3:0] <= nib;       // P: must win for low nibble
      q[7:4] = nib + 1;    // B: visible to the following read
      seen <= q;
    end
  end
endmodule
module tb_partial_blocking;
 logic clk=0,rst=1; logic [3:0] nib; logic [7:0] q,seen;
 partial_blocking dut(.*); always #5 clk=~clk;
 initial begin nib=4'h3; @(negedge clk); rst=0; @(posedge clk); #1;
   if(q!==8'h43 || seen!==8'h40) $fatal(1,"partial q=%h seen=%h",q,seen);
   $display("PASS"); $finish(0); end
endmodule
