module sv_wait_order_synthesis(input wire clk, output reg result);
  event first, second;

  always @(posedge clk)
    wait_order(first, second)
      result <= 1'b1;
    else
      result <= 1'b0;
endmodule
