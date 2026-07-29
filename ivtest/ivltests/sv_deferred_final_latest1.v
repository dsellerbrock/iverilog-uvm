module t;
  int x = 0;

  // 16.4: condition evaluated AT EXECUTION; report deferred to end of
  // simulation. Instance A: one execution, false -> fail arm at end.
  initial begin
    x = 1;
    assert final (x == 3) else $display("A: fail arm at end (correct)");
  end

  // Instance B: the SAME statement executes twice (false at t0, true
  // at t2); the latest evaluation wins -> exactly one pass-arm report.
  initial begin
    repeat (2) begin
      assert final (x == 2) $display("B: pass arm at end (correct)");
        else $display("FAILED B: stale first evaluation reported");
      #2 x = 2;
    end
  end

  initial #5 $display("end of active stimulus");
endmodule
