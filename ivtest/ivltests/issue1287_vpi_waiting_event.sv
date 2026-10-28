module top;
  event ev;
  initial begin @ev; end
  initial begin #2 -> ev; end
endmodule
