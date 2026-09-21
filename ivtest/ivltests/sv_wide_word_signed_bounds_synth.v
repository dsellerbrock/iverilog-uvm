module wide_signed_nonzero_descending_bounds(input logic clk,
  output logic [7:0] neg_m2, neg_m1, desc4, desc3);
  logic [7:0] neg_mem [-2:-1];
  logic [7:0] desc_mem [4:3];
  always_ff @(posedge clk) begin
    neg_mem[-80'sd2] <= 8'h12;
    neg_mem[-80'sd1] <= 8'h13;
    desc_mem[80'sd4] <= 8'h44;
    desc_mem[80'sd3] <= 8'h43;
    // Invalid signed, oversized, and four-state selectors select no word.
    neg_mem[-80'sd3] <= 8'hee;
    desc_mem[80'h1_0000_0000_0000_0000] <= 8'hef;
    neg_mem[80'hx] <= 8'hdd;
    desc_mem[80'hz] <= 8'hcc;
  end
  assign neg_m2=neg_mem[-2]; assign neg_m1=neg_mem[-1];
  assign desc4=desc_mem[4]; assign desc3=desc_mem[3];
endmodule
module tb_wide_signed_nonzero_descending_bounds;
  logic clk=0; logic [7:0] neg_m2,neg_m1,desc4,desc3;
  wide_signed_nonzero_descending_bounds dut(.*);
  initial begin #1 clk=1; #1 clk=0;
    if ({neg_m2,neg_m1,desc4,desc3} !== 32'h12134443)
      $fatal(1,"bad fixed-array canonical bounds %h %h %h %h",neg_m2,neg_m1,desc4,desc3);
    $display("PASS"); $finish(0);
  end
endmodule
