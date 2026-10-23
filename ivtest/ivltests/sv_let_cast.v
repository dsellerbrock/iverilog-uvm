module sv_let_cast;
  logic [3:0] a = 4'hf;
  let mult(x, y) = ($bits(x) + $bits(y))'(x * y);
  let m2(x, y) = 8'(x * y);
  let c3(x) = int'(x);

  initial begin
    if (mult(a, a) !== 16'd225)
      $fatal(1, "mult cast let mismatch: %0d", mult(a, a));
    if (m2(a, a) !== 8'd225)
      $fatal(1, "size cast let mismatch: %0d", m2(a, a));
    if (c3(a) !== 32'd15)
      $fatal(1, "type cast let mismatch: %0d", c3(a));
    $display("PASSED");
  end
endmodule
