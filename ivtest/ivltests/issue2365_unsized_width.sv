// IEEE 1800 5.7.1 / Table 11-21: an unsized decimal number is as wide as
// integer (32 bits), so 2147483647 + 1 wraps. Default for -g2017/-g2023.
module top;
  initial begin
    $display("%0d", 2147483647 + 1);
    $display("%0d", 1 << 40);
    $display("%0d", $bits(2147483647 + 1));
  end
endmodule
