// IEEE 1800-2023 5.7.1: an unsized number is at least 32 bits wide. Under the
// 32-bit default of -g2017/-g2023 a literal that needs more keeps its width.
module top;
  initial begin
    $display("%0d %0d", 4294967296, 2147483648);
    $display("%0d", 2147483647 + 1);
  end
endmodule
