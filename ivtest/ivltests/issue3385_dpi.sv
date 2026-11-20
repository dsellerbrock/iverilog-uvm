module issue3385_dpi;
  import "DPI-C" pure issue3385_adjust = function int adjust(input int);

  initial begin
    if (adjust(13) !== 38)
      $fatal(1, "Wrong DPI-C result for an unnamed formal");
    $display("PASSED");
  end
endmodule
