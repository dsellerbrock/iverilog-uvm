module svdpi_bitsel_selfcheck;
  import "DPI-C" function int c_svdpi_bitsel_selfcheck();
  initial begin
    int result;
    result = c_svdpi_bitsel_selfcheck();
    if (result != 0) $fatal(1, "DPI bit-select helper failure %0d", result);
    $display("PASS svdpi bit-select helpers");
  end
endmodule
