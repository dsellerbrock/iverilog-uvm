// Regression: process::suspend() / process::resume() real semantics.
//
// Fork two threads.  Each captures its process handle, then self-
// suspends.  The main thread waits for both handles to be non-null,
// records each thread's status (should be SUSPENDED=3), then resumes
// them.  After resume both threads display their id and end; the
// monitor verifies that both ids printed AFTER the resume.

module top();
   process h0, h1;
   int     status0, status1;
   bit     ran0, ran1;
   int     phase;

   initial begin
      ran0 = 0; ran1 = 0; phase = 0;
      fork
         begin
            h0 = process::self();
            h0.suspend();
            ran0 = 1;
            $display("thread0 ran phase=%0d", phase);
         end
         begin
            h1 = process::self();
            h1.suspend();
            ran1 = 1;
            $display("thread1 ran phase=%0d", phase);
         end
      join_none

      // Wait for both threads to publish their handles and suspend.
      wait(h0 != null && h1 != null);
      // Give both threads a microstep to call .suspend() before we read status.
      #1;
      status0 = h0.status;
      status1 = h1.status;
      // Neither thread should have advanced past suspend yet.
      if (ran0 || ran1) begin
         $display("FAILED: thread ran before resume; ran0=%0d ran1=%0d", ran0, ran1);
         $finish;
      end
      // Resume both.
      phase = 1;
      h0.resume();
      h1.resume();
      // Yield so they execute.
      #1;
      if (status0 == 3 && status1 == 3 && ran0 && ran1)
         $display("PASSED");
      else
         $display("FAILED status0=%0d status1=%0d ran0=%0d ran1=%0d",
                  status0, status1, ran0, ran1);
      $finish;
   end
endmodule
