// IEEE 1800-2017/2023 §15.5.1–§15.5.2: blocking event trigger and control.
module test;
  event e;
  bit passed = 0;
  initial begin
    fork
      begin
        #10;
        -> e;
      end
      begin
        @e;
        if ($time != 10) $fatal(1, "FAIL 15.5.1/2: woke at %0t", $time);
        passed = 1;
        $display("PASS 15.5.1/2 basic event at %0t", $time);
      end
    join
  end
  initial begin
    #20;
    if (!passed) $fatal(1, "FAIL 15.5.1/2: event wait timed out");
  end
endmodule
