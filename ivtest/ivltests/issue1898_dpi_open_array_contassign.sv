module issue1898_dpi_open_array_contassign;
  import "DPI-C" function int c_sum(input int a[]);
  int fa[2], continuous_result, procedural_result;

  assign continuous_result = c_sum(fa);
  always_comb procedural_result = c_sum(fa);

  initial begin
    #1 fa[1] = 5;
    #1;
    if (continuous_result !== 5 || procedural_result !== 5)
      $fatal(1, "ISSUE1898_FAIL continuous=%0d procedural=%0d",
             continuous_result, procedural_result);
    $display("ISSUE1898_PASS");
    $display("PASSED");
  end
endmodule
