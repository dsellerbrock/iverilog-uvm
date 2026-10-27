interface class I;
  pure virtual function int value();
endclass

module top;
  I h;
  initial begin
    h.rand_mode(0);
    h.constraint_mode(0);
  end
endmodule
