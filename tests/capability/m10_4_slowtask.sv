// M10-4: time-consuming imported DPI task (coroutine path) --
// imported context task calls an exported task that consumes time.
module top;
  import "DPI-C" context task c_slow(input int d);
  export "DPI-C" task sv_wait;
  int done_at = -1;
  task sv_wait(input int d); #(d) done_at = $time; endtask
  initial begin
    int ok = 1;
    c_slow(5);
    if ($time != 5) begin $display("FAIL time after c_slow t=%0t (expect 5)", $time); ok = 0; end
    if (done_at != 5) begin $display("FAIL done_at=%0d", done_at); ok = 0; end
    c_slow(7);
    if ($time != 12) begin $display("FAIL time after 2nd c_slow t=%0t (expect 12)", $time); ok = 0; end
    if (ok) $display("PASS m10_4");
    $finish(0);
  end
endmodule
