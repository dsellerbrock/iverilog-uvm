module concat_order(input logic clk, rst, input logic [7:0] add,
                    output logic [7:0] q, r);
  always_ff @(posedge clk) begin
    if (rst) begin q <= 0; r <= 0; end
    else begin
      q = 8'h10;
      r = 8'h20;
      {q,r} <= {q,r} + add; // RHS samples B (10,20); NBA commits last.
      q = 8'hee;
      r = 8'hef;
    end
  end
endmodule
module tb_concat_order;
  logic clk=0,rst=1; logic [7:0] add,q,r;
  concat_order dut(.*); always #5 clk=~clk;
  initial begin
    add=8'h05;
    @(negedge clk); rst=0;
    @(posedge clk); #1;
    if ({q,r} !== 16'h1025) $fatal(1,"concat q,r=%h,%h",q,r);
    $display("PASS"); $finish(0);
  end
endmodule
