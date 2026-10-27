`timescale 1ns/1ps
module p20_04_1_tu;
  sub u();
  initial $display("TU %0d %0d %0d %0d", $timeunit, $timeprecision, $timeunit(u), $timeprecision(u));
endmodule
`timescale 100us/10ns
module sub; endmodule
