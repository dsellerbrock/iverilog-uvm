checker c(input logic clk, output bit result);
  assign result = clk;
endchecker

module issue1553_checker_output_reactive_2023;
  logic clk = 0, result, sampled;
  c ci(clk, result);

  always @(posedge clk) sampled <= result;

  initial begin
    #5 clk <= 1;
    #1;
    if (result !== 1'b1 || sampled !== 1'b0)
      $fatal(1, "result=%b sampled=%b", result, sampled);
    $display("PASS result=%b sampled=%b", result, sampled);
    $finish;
  end
endmodule
