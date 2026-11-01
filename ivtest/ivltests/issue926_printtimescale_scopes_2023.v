timeunit 100ps / 10fs;

module issue926_printtimescale_scopes;
  timeunit 1ms / 1us;

  initial begin
    $printtimescale($root);
    $printtimescale($unit);
    $display("PASSED");
    $finish;
  end
endmodule
