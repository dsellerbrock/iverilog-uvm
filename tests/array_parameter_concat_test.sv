// IEEE 1800-2017 10.10: unpacked array concatenation initializer.
package array_parameter_concat_pkg;
  parameter string Alerts[2] = {"recoverable", "fatal"};
endpackage

module array_parameter_concat_test;
  string copy[2];
  initial begin
    copy = array_parameter_concat_pkg::Alerts;
    if (copy[0] == "recoverable" && copy[1] == "fatal"
        && array_parameter_concat_pkg::Alerts[1] == "fatal")
      $display("PASS: array parameter concatenation");
    else
      $display("FAIL: array parameter concatenation '%s' '%s'",
               copy[0], copy[1]);
    $finish;
  end
endmodule
