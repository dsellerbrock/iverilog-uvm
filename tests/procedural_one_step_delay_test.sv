module procedural_one_step_delay_test;
  timeunit 1ns;
  timeprecision 1ps;

  initial begin
    #1step;
    if ($realtime != 0.001ns) begin
      $display("FAIL: #1step advanced to %0t", $realtime);
      $finish(1);
    end
    $display("PASS: procedural #1step advances one precision tick");
    $finish;
  end
endmodule
