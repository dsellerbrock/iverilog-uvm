module tb;
  reg a, b, x, y;
  initial begin
    x = a ~& b;
    y = a ~| b;
  end
endmodule
