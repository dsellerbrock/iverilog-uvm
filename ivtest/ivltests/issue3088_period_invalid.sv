module top(input clk, enable);
  specify
    $period(clk, 3);
    $period(clk &&& enable, 3);
  endspecify
endmodule
