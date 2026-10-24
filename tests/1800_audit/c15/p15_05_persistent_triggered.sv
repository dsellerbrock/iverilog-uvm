// IEEE 1800-2017/2023 §15.5.3: triggered remains true in the current time step.
module test;
  event e;
  bit passed = 0;
  initial begin
    #10;
    -> e;
    wait (e.triggered);
    passed = 1;
    $display("PASS 15.5.3 persistent event trigger at %0t", $time);
  end
  initial begin
    #20;
    if (!passed) $fatal(1, "FAIL 15.5.3: wait(e.triggered) timed out");
  end
endmodule
