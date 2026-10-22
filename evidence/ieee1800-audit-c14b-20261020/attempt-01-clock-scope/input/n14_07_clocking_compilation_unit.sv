bit clk = 0;
clocking cb @(posedge clk);
  input clk;
endclocking
module top;
  initial begin
    #1;
    $display("UNEXPECTED_COMPILATION_UNIT_CLOCKING");
    $finish;
  end
endmodule
