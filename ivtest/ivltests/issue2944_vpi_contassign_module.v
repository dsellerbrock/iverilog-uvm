module top;
  logic a = 0;
  if (1) begin : g
    wire gw;
    assign gw = a;
  end
  initial begin #1 $probe; $display("PASSED"); end
endmodule
