module issue1897_dpi_sized_array_always_comb;
  import "DPI-C" function int c_sum(input int a[4]);

  int a[4], r;
  bit enable = 0;

  always_comb begin
    if (enable) r = c_sum(a);
    else r = 0;
  end

  initial begin
    #1;
    if (r == 0) $display("PASSED");
    else $display("FAILED %0d", r);
  end
endmodule
