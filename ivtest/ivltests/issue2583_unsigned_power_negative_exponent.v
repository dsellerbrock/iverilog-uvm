module issue2583_unsigned_power_negative_exponent;
  logic [7:0] u = 8'hff;
  logic signed [7:0] s = -1;
  int n = -1;

  initial begin
    if (u ** n !== 0 || u ** -2 !== 0)
      $fatal(1, "unsigned base negative powers: %0d %0d", u ** n, u ** -2);
    if (s ** n !== -1 || s ** -2 !== 1)
      $fatal(1, "signed base negative powers: %0d %0d", s ** n, s ** -2);
    if (u ** 2 !== 8'h01)
      $fatal(1, "positive exponent: %0d", u ** 2);
    $display("PASSED: signedness-aware negative integer powers");
    $finish;
  end
endmodule
