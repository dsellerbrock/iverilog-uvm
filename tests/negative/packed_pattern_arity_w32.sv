// IEEE 1800-2017 10.9.2: 3 elements onto logic[31:0] is an arity
// error. A "misparse tolerance" hatch used to accept any pattern of
// <=8 elements onto a 32-bit packed target and truncate each element
// to a single bit (recovery D6).
module top;
  logic [31:0] x32 = '{3{8'hFF}};
  initial $display("x32=%h", x32);
endmodule
