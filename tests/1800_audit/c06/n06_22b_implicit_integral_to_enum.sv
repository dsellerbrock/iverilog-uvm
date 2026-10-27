typedef enum logic [1:0] { E0 = 2'b00, E1 = 2'b01, E2 = 2'b10 } e_t;
module top;
  e_t e;
  initial e = 2;
endmodule
