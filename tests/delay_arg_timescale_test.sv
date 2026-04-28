// Phase 43 repro: `#(N * 1ns)` collapses to 0 ticks unless an explicit
// timescale is set. OpenTitan DV depends on this for DV_WAIT_TIMEOUT.

`timescale 1ns/1ps

package my_pkg;
  typedef bit [31:0] uint;
  uint default_timeout_ns = 2_000_000;
endpackage

module top;
  import my_pkg::*;
  task automatic wait_with(uint timeout_ns = default_timeout_ns);
    #(timeout_ns * 1ns);
  endtask

  initial begin
    wait_with();
    // Timescale is 1ns/1ps -> $time is in ns units.
    if ($time != 2_000_000) $display("FAIL: expected $time=2_000_000 (ns), got %0d", $time);
    else $display("PASS");
    $finish;
  end
endmodule
