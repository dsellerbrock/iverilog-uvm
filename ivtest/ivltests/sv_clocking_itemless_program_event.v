// An itemless program-block clocking block is a post-NBA synchronization
// event.  Returning from the only program initial block must then terminate
// simulation; the compiler-generated clocking machinery is not a user program
// procedure that keeps the program alive.
`timescale 1ns/1ps

program itemless_program(input logic clk, input int nba_stage1,
                         input int nba_stage2);
  int hits = 0;
  int failures = 0;

  clocking cb @(posedge clk);
  endclocking

  initial begin
    repeat (3) begin
      @(cb);
      hits++;
      if ($time != (hits * 10 - 5) * 1ns || nba_stage1 != hits ||
          nba_stage2 != hits) begin
        failures++;
        $display("FAILED program hit=%0d time=%0t stage1=%0d stage2=%0d",
                 hits, $time, nba_stage1, nba_stage2);
      end
    end

    if (failures != 0)
      $fatal(1, "%0d itemless program clocking-event checks failed", failures);
    $display("PASSED");
    // No explicit $finish: IEEE program completion ends simulation.  This
    // also catches a generated clocking process being counted as a live
    // program procedure.
  end
endprogram

module sv_clocking_itemless_program_event;
  logic clk = 1'b0;
  int nba_stage1 = 0;
  int nba_stage2 = 0;

  always #5 clk = ~clk;

  always @(posedge clk)
    nba_stage1 <= nba_stage1 + 1;

  always @(nba_stage1)
    nba_stage2 <= nba_stage1;

  itemless_program test_program(clk, nba_stage1, nba_stage2);
endmodule
