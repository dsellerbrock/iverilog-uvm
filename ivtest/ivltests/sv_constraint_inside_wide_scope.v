// A 128-bit queue operand sizes the whole inside expression to 128 bits
// (IEEE 1800-2017/2023 11.4.13, 11.6): (250 + 10) / 2 is 130 there, not
// the 8-bit wrapped value 2.
module test;
  bit [7:0] a, b;
  bit [127:0] q [$];
  initial begin
    if (std::randomize(a, b) with {
          a == 250; b == 10;
          int'(((a + b) / 8'd2) inside {q, 8'd2}) == 1; })
      $fatal(1, "8-bit wrapped result accepted");
    q.push_back(128'd130);
    if (!std::randomize(a, b) with {
          a == 250; b == 10;
          int'(((a + b) / 8'd2) inside {q, 8'd2}) == 1; })
      $fatal(1, "128-bit result rejected");
    $display("PASSED");
  end
endmodule
