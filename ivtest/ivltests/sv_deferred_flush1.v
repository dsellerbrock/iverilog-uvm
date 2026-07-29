module t;
  int x = 0;
  int reports = 0;

  // Same-step re-execution: the loop runs the SAME assertion statement
  // five times in one time step with different verdicts; only the LAST
  // evaluation may report (16.4.4 flush), and x==4 passes, so the else
  // arm must NOT fire at all in step 0.
  initial begin
    for (int i = 0; i < 5; i++) begin
      x = i;
      assert #0 (x == 4) reports++; else begin reports += 100; $display("FAILED flushed report fired, x=%0d", x); end
    end
  end

  // One report per step, taking the settled value of each step.
  int step_reports = 0;
  initial begin
    #1;
    assert #0 (1) step_reports++;
    assert #0 (1) step_reports++;
    #1;
    assert #0 (0) else step_reports += 10;
    #1;
    if (reports !== 1) $display("FAILED same-step flush: reports=%0d (want 1)", reports);
    else if (step_reports !== 12) $display("FAILED per-step: step_reports=%0d (want 12)", step_reports);
    else $display("PASSED");
  end
endmodule
