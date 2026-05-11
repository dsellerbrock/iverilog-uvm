// Regression: `@<sequence>` blocks until the sequence's terminal
// boolean evaluates true at the sequence's clocking event.  Covers
// the simple linear `##d` chain case used by chapter-9/9.4.2.4.

module top();
   logic clk = 0;
   logic a = 0, b = 0, c = 0;
   int   seen_at = -1;

   sequence seq;
      @(posedge clk) a ##1 b ##1 c;
   endsequence

   initial begin
      // Stimulus: drive a, b, c such that the sequence completes at
      // the third posedge clk (t=50ns).
      a = 1;
      #10 clk = 1;   // t=10
      #10 clk = 0;   // t=20
      b = 1;         // t=20
      #10 clk = 1;   // t=30
      #10 clk = 0;   // t=40
      c = 1;         // t=40
      #10 clk = 1;   // t=50 — sequence completes
      #10 clk = 0;
      #10;
      // If `@seq` waited correctly, seen_at should equal 50.
      if (seen_at == 50) $display("PASSED");
      else $display("FAILED seen_at=%0d", seen_at);
      $finish;
   end

   initial begin
      @seq;
      seen_at = $time;
   end
endmodule
