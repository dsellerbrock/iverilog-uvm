// M6B: simulation ends when all program blocks complete
// (IEEE 1800-2017 24.7 / 3.9). Previously a program that completed
// naturally did NOT end the simulation (it ran to the watchdog). Now
// the runtime counts program INITIAL procedures and implicitly finishes
// when the last one completes. Concurrent/always-type program items do
// not keep the sim alive (only run-once initials are counted).
//
// This test has NO explicit $finish in the programs: if program
// completion did not end the simulation, the watchdog fires FAIL.
// Two programs of different lengths verify the sim ends only after the
// LAST program completes (not the first).
module m6b_program_finish_test_top;
  logic clk = 0;
  always #5 clk = ~clk;

  int a_done_time = 0;
  int b_done_time = 0;

  program pa;
    initial begin
      repeat (2) @(posedge clk);          // completes at t=15
      a_done_time = $time;
      $display("PASS: program A completed at t=%0t", a_done_time);
    end
  endprogram

  program pb;
    initial begin
      repeat (4) @(posedge clk);          // completes at t=35 (later)
      b_done_time = $time;
      $display("PASS: program B completed at t=%0t; sim should now end", b_done_time);
    end
  endprogram

  // Watchdog: if program completion did NOT end the simulation, fail loudly.
  initial begin
    #100000;
    $display("FAIL: m6b program completion did not end the simulation");
    $finish(1);
  end
endmodule
