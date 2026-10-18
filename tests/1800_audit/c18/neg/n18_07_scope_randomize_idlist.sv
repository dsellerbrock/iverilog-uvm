module top;
  int a;
  initial void'(std::randomize(a) with (a) { a < 3; });
endmodule
