module tb;
  typedef enum bit [99:0] { A = 0, B = 1 } e_t;
  e_t v = B;
  initial $display("%0d", v);
endmodule
