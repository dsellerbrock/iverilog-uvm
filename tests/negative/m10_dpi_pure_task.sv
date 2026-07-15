// M10: a DPI import task cannot be declared pure (IEEE1800-2017 35.4).
module m10_dpi_pure_task;
  import "DPI-C" pure task c_bad_task(int x);
endmodule
