// IEEE 1800-2017/2023 9.7: a process suspended while waiting on a named
// event must wait for a new occurrence after resume().
module sv_process_resume_event_rearm;
  event ev;
  process waiter;
  bit done = 0;
  bit failed = 0;

  initial begin
    fork
      begin
        waiter = process::self();
        @ev;
        done = 1;
      end
    join_none

    wait (waiter != null);
    #0;
    waiter.suspend();
    -> ev;
    #0;
    if (done !== 0 || waiter.status() != process::SUSPENDED) begin
      $display("FAIL: event woke suspended process");
      failed = 1;
    end

    waiter.resume();
    #0;
    if (done !== 0 || waiter.status() != process::WAITING) begin
      $display("FAIL: resume replayed suspended event (done=%0d status=%0d)",
               done, waiter.status());
      failed = 1;
    end

    -> ev;
    #0;
    if (done !== 1 || waiter.status() != process::FINISHED) begin
      $display("FAIL: process did not wake on next event (done=%0d status=%0d)",
               done, waiter.status());
      failed = 1;
    end

    if (failed) $display("FAILED");
    else $display("PASSED");
    $finish(0);
  end
endmodule
