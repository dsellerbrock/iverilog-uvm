module top;
  class K; static function int dbl(int x); return x * 2; endfunction endclass
  int a = 3; wire [31:0] y; assign y = K::dbl(a);
  initial begin #1 $display("%s 13.8.assign_plain_static_method y=%0d", y == 6 ? "PASS" : "FAIL", y); end
endmodule
