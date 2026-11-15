// IEEE 1800-2023 31.8 with -gneg-tchk: the delayed reference and data
// views of a vector terminal are one check, sized by the signal they delay.
`timescale 1ns/1ns
module issue3288_vector_tchk_neg_dut(input [1:0] clk, input [1:0] d);
  reg ntf = 0;
  wire [1:0] dclk, dd;
  specify
    $setuphold(posedge clk, d, -1, 3, ntf, , , dclk, dd);
  endspecify
endmodule
module issue3288_vector_tchk_neg;
  reg [1:0] clk = 0, d = 0;
  issue3288_vector_tchk_neg_dut u(clk, d);
  initial begin
    #10 clk = 2'b10;          // bit 1 rises
    #2  d = 2'b11;            // bit 1 only rises at 10: one check
    #10 clk = 2'b00; #10 clk = 2'b11; #2 d = 2'b00;  // both bits rise at 32: one violation
    #5 $display("ntf=%b", u.ntf);
    #5 $finish;
  end
endmodule
