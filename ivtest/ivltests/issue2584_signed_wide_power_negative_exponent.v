module issue2584_signed_wide_power_negative_exponent;
  logic signed [99:0] z = 0, m = -1, n = -1;
  logic signed [0:0] narrow_m = -1;

  initial begin
    $display("%0d %0d %0d %0d", z ** n, m ** n, m ** (n + n), narrow_m ** n);
    $finish;
  end
endmodule
