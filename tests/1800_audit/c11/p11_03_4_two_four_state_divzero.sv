module p11_03_4_two_four_state_divzero;
  int n = 8, zero = 0;
  int two_state_result;
  integer four_state_result;

  initial begin
    two_state_result = n / zero + n;
    four_state_result = n / zero + n;
    if (two_state_result !== 0 || four_state_result !== 'x)
      $fatal(1, "FAIL two_state=%b four_state=%b",
             two_state_result, four_state_result);
    $display("PASS two_state=%0d four_state=%b",
             two_state_result, four_state_result);
  end
endmodule
