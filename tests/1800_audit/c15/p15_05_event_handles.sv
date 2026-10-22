// IEEE 1800-2017/2023 §15.5.5: event assignment merges event variables.
module test;
  event e1, e2;
  bit passed = 0;
  initial begin
    e1 = e2;
    if (!(e1 == e2)) $fatal(1, "FAIL 15.5.5: merged events compare unequal");
    fork
      begin
        #10;
        -> e2;
      end
      begin
        @e1;
        if ($time != 10) $fatal(1, "FAIL 15.5.5: woke at %0t", $time);
        passed = 1;
        $display("PASS 15.5.5 event merge and equality");
      end
    join
  end
  initial begin
    #20;
    if (!passed) $fatal(1, "FAIL 15.5.5: merged event wait timed out");
  end
endmodule
