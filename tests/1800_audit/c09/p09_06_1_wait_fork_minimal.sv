module top; int d, g; time t0;
  initial begin
    t0 = $time;
    fork begin fork #50 d = 1; join_none end join_none
    wait fork;
    $display("INFO elapsed=%0d d=%0d", $time - t0, d);
    $display("%s 9.6.1.minimal_ignores_descendant", (($time - t0) == 0 && d == 0) ? "PASS" : "FAIL");
    t0 = $time;
    fork #7 g = 1; join_none
    wait fork;
    $display("%s 9.6.1.minimal_waits_for_immediate_child (elapsed=%0d)", (($time - t0) == 7 && g == 1) ? "PASS" : "FAIL", $time - t0);
    $finish;
  end
endmodule
