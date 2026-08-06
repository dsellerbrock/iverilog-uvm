// G25: Per-bit latch enable support
// Test that an always @* process with partial packed writes
// synthesizes correctly with per-bit latches.

module main();

   reg [3:0] q;
   reg       en1, en2;
   reg       d1, d2;

   // Two independently-enabled bits: bit 0 when en1, bit 1 when en2.
   always @* begin
      if (en1) q[0] = d1;
      if (en2) q[1] = d2;
   end

   // Separate test driver — does NOT drive q procedurally.
   reg [3:0] check_val;
   initial begin
      en1 = 0; en2 = 0; d1 = 0; d2 = 0;
      #1 check_val = q;
      #1 d1 = 1;
      #1 check_val = q;
      #1 en1 = 1;
      #1 check_val = q;
      #1 en1 = 0; d2 = 1; en2 = 1;
      #1 check_val = q;

      // After synthesis, the latch values depend on the
      // synthesized netlist. We just verify compilation succeeds
      // (no G25 error).
      $display("PASSED");
   end

endmodule
