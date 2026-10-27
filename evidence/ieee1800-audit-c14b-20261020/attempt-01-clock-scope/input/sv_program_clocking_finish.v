// A program whose only post-initial activity is a clocking block must still end
// the simulation when its initial procedures complete (IEEE 1800-2017 24.7).
// The synthesized clocking sampler is an INITIAL wrapping a forever loop; it
// was wrongly tagged as a program procedure, so the program-completion count
// never reached zero and the simulation hung forever. The sampler (and the
// output-apply process) are now excluded from that count.
//
// Self-checking: the program samples through its clocking block, prints PASSED,
// and completes — which must end the simulation before the module watchdog at
// time 1000. If the sim failed to end, the watchdog prints FAILED instead.
program automatic p(input bit clk, input logic [7:0] d);
  clocking cb @(posedge clk);
    input d;
  endclocking
  initial begin
    @(cb);
    if (cb.d === 8'h42) $display("PASSED");
    else $display("FAILED (cb.d=%0h, expected 42)", cb.d);
    // Program completes here -> simulation must end (no explicit $finish).
  end
endprogram

module sv_program_clocking_finish;
  bit clk = 0;
  always #5 clk = ~clk;
  logic [7:0] d = 8'h42;
  p pp(clk, d);

  // If program completion does NOT end the sim, this watchdog fires.
  initial begin
    #1000;
    $display("FAILED (simulation did not end on program completion)");
    $finish;
  end
endmodule
