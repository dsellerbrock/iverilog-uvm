// M6B-3: a time-consuming DPI import must participate in normal
// scheduling -- join_any / disable fork must be able to abandon it.
module top;
  import "DPI-C" context task c_slow(input int d);
  export "DPI-C" task sv_wait;
  int late = 0;
  task sv_wait(input int d); #(d) late = 1; endtask
  initial begin
    int ok = 1;
    fork
      begin c_slow(50); $display("  slow branch returned t=%0t", $time); end
      begin #3; $display("  fast branch done t=%0t", $time); end
    join_any
    disable fork;
    if ($time != 3) begin $display("FAIL join_any t=%0t (expect 3)", $time); ok = 0; end
    #10;
    if (late != 0) begin $display("FAIL disabled DPI task still completed"); ok = 0; end
    if (ok) $display("PASS m6b3_kill");
    $finish(0);
  end
endmodule
