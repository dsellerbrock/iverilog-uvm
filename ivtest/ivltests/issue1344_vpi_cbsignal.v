// Issue #1344: a cbSignal callback traps an operating-system signal and
// runs at the next safe point (IEEE 1800-2023 38.36.3); simulation goes on.
module top;
  initial begin
    $raise_usr1;
    #5 $display("DONE");
    $report;
  end
endmodule
