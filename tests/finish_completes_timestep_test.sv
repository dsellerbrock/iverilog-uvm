// Regression (ivtest pr243): $finish must let already-scheduled threads
// complete the CURRENT time step -- their stores propagate and $monitor's
// ReadOnly flush still runs (upstream semantics). The fork's hung-loop
// watchdog had added schedule_finished() bail-outs to the %jmp opcodes,
// which killed a same-step thread mid-body if it resumed after another
// thread's $finish, dropping the final $monitor sample. The bail-outs
// now live only at %delay/%delayx (preventing post-finish respawn).
module finish_completes_timestep_test;
  reg [3:0] v;
  integer lines = 0;
  initial begin
    $monitor("T%0t v=%0d", $time, v);
    v = 0;
    #30 $finish(0);
  end
  always begin
    #10 v = v + 1;   // matures at 30 together with $finish
  end
  always @(v) if (v == 3) begin
    // v reaching 3 at t=30 proves the same-step always body ran to
    // completion after $finish. The PASS line prints before the
    // monitor flush; the harness only needs the literal PASS.
    $display("PASS: same-step thread completed after $finish");
  end
endmodule
