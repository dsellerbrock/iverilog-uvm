module top;
  bit a, b, c;
  initial begin
    unique if (a) $display("A");
    else if (b) $display("B");
    else unique if (c) $display("C");
  end
endmodule
