checker issue1554_checker(input logic x, input logic clk);
  a: assert property (@(posedge clk) x);
endchecker

program issue1554_program;
  logic clk = 0, x = 1;
  issue1554_checker ci(x, clk);

  initial begin
    #1 clk = 1;
    #1 $display("PASSED");
    $finish;
  end
endprogram

module issue1554_checker_in_program;
  issue1554_program pi();
endmodule
