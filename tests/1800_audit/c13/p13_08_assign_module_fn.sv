module top;
  function int dbl(int x); return x * 2; endfunction
  int a = 3; wire [31:0] y; assign y = dbl(a);
  initial begin #1 $display("%s 13.4.control_module_fn_in_assign y=%0d", y == 6 ? "PASS" : "FAIL", y); end
endmodule
