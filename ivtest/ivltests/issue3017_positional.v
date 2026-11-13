class c #(int WIDTH = 2);
  parameter int DOUBLE = WIDTH * 2;
endclass
module test;
  initial $display("%0d", c#(3, 99)::DOUBLE);
endmodule
