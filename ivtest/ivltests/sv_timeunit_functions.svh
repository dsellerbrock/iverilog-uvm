timeunit 10us;
timeprecision 1us;

package timeunit_test_pkg;
  timeunit 1us;
  timeprecision 10ns;
endpackage

module timeunit_test_child;
  timeunit 1ns;
  timeprecision 10ps;
endmodule

module timeunit_test_dut;
  timeunit 10ns;
  timeprecision 100ps;
  timeunit_test_child child();
endmodule

module test;
  timeunit 100ns;
  timeprecision 1ns;
  timeunit_test_dut dut();

  initial begin
    if ($timeunit != -7 || $timeunit() != -7)
      $fatal(1, "current time unit mismatch");
    if ($timeprecision != -9 || $timeprecision() != -9)
      $fatal(1, "current time precision mismatch");
    if ($timeunit(dut) != -8 || $timeprecision(dut) != -10)
      $fatal(1, "selected module timescale mismatch");
    if ($timeunit(dut.child) != -9 || $timeprecision(dut.child) != -11)
      $fatal(1, "selected child timescale mismatch");
    if ($timeunit(timeunit_test_pkg) != -6
        || $timeprecision(timeunit_test_pkg) != -8)
      $fatal(1, "selected package timescale mismatch");
    if ($timeunit($unit) != -5 || $timeprecision($unit) != -6)
      $fatal(1, "compilation unit timescale mismatch");
    if ($timeunit($root) != -11 || $timeprecision($root) != -11)
      $fatal(1, "root simulation timescale mismatch");
    $display("PASSED");
  end
endmodule

module timeunit_functions_invalid;
  initial $display("%0d", $timeunit(1));
endmodule
