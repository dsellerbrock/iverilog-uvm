// Regression: an automatic task invoked concurrently, whose body contains an
// unnamed inner fork/join that writes and senses the task's own automatic
// locals. The fork previously gave the unnamed inner fork its own synthesized
// ($unm_blk) scope and, since the task is automatic, allocated a spurious
// per-block activation frame for it. That empty frame became the current
// activation context, so the inner fork branches could not resolve the
// enclosing task's per-invocation locals -- with two concurrent activations
// the locals read x and the outputs were wrong. The fix drops the empty
// unnamed-fork scope (as the begin/end path already did), so the inner fork
// shares the single task frame.
//
// Two concurrent activations must keep their locals isolated.
module top;
  task automatic worker(input byte id, output byte result);
    reg [7:0] acc;            // per-activation automatic local
    acc = 8'h00;
    fork                      // unnamed inner fork with no locals of its own
      begin #10 acc = id; end
      begin @(acc) result = acc; end
    join
  endtask

  byte r1, r2;
  initial begin
    fork
      worker(8'hA1, r1);
      worker(8'hB2, r2);
    join
    if (r1 === 8'hA1 && r2 === 8'hB2)
      $display("PASS: concurrent auto-task frame isolation (r1=%0h r2=%0h)", r1, r2);
    else
      $display("FAIL: r1=%0h r2=%0h expected a1/b2", r1, r2);
    $finish;
  end
endmodule
