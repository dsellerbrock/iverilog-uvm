// IEEE 1800-2017/2023 35.9(b): a normally returning imported task must
// return 0 from C. Returning 1 without a disable is a protocol error.
`timescale 1ns/1ns

module top;
  import "DPI-C" task dpi_bad_normal_task();

  initial begin
    dpi_bad_normal_task();
    #1;
    $display("UNEXPECTED: normal imported task returning 1 was accepted");
    $finish(0);
  end
endmodule
