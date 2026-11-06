module issue2583_unsigned_power_negative_exponent;
  logic [7:0] u = 8'hff;
  int n = -1;

  initial begin
    $display("%0d %0d", u ** n, u ** -2);
    $finish;
  end
endmodule
