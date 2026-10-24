module ns_scope;
  timeunit 1ns;
  timeprecision 1ps;
  initial begin
    #1;
    if ($time !== 1 || $realtime != 1.0 || $stime !== 1)
      $fatal(1, "FAIL ns scope: %0t %0.3f %0d", $time, $realtime, $stime);
    $display("PASS ns scope: time=%0d realtime=%0.3f stime=%0d",
             $time, $realtime, $stime);
  end
endmodule

module ps_scope;
  timeunit 1ps;
  timeprecision 1ps;
  initial begin
    #1000;
    if ($time !== 1000 || $realtime != 1000.0 || $stime !== 1000)
      $fatal(1, "FAIL ps scope: %0t %0.3f %0d", $time, $realtime, $stime);
    $display("PASS ps scope: time=%0d realtime=%0.3f stime=%0d",
             $time, $realtime, $stime);
  end
endmodule
