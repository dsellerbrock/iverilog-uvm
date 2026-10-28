module issue1253_invalid_dpi_linkage;
  import "DPI-C" bad$name = function int c_value();
endmodule
