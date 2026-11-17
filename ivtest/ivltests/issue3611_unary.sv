module tb;
  reg [1:0] a;
  initial begin
    a = 2'b11;
    if ((~&a) !== 1'b0 || (~|a) !== 1'b0) $fatal(1, "unary reductions failed");
    a = 2'b00;
    if ((~&a) !== 1'b1 || (~|a) !== 1'b1) $fatal(1, "unary reductions failed");
    $display("PASS");
  end
endmodule
