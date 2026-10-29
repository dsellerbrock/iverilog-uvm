module coarse;
  timeunit 1ns / 100ps;
  initial begin
    #1step;
    if (($realtime - 0.001) > 0.00001 || ($realtime - 0.001) < -0.00001)
      $fatal(1, "step=%0.5f ns", $realtime);
    $display("PASSED");
  end
endmodule

module fine; timeunit 1ns / 10ps; endmodule

module tb;
  timeunit 1ns / 1ps;
  coarse c();
  fine f();
  initial #1ns $finish;
endmodule
