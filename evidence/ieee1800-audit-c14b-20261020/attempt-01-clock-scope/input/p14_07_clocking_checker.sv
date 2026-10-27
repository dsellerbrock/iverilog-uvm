checker checker_cb(input logic clk);
  clocking cb @(posedge clk);
    input clk;
  endclocking
endchecker
module top;
  logic clk = 0;
  checker_cb c(clk);
  initial begin
    #1;
    $display("CHECKER_CLOCKING_SCOPE_OK");
    $finish;
  end
endmodule
