// IEEE 1800-2017/2023 9.3.2, 9.6.1 and 9.6.3.
// A singleton child waits for or disables only its own descendants.
module main;
  bit survivor;
  process caller, worker;
  bit ran, joined;
  initial begin
    fork #10 survivor = 1; join_none
    fork wait fork; join
    if ($time != 0) $fatal(1, "singleton join waited for a sibling");
    #20;
    if (!survivor) $fatal(1, "join wait control lost its sibling");

    survivor = 0;
    fork #10 survivor = 1; join_none
    fork wait fork; join_any
    if ($time != 20) $fatal(1, "singleton join_any waited for a sibling");
    #20;
    if (!survivor) $fatal(1, "join_any wait control lost its sibling");

    survivor = 0;
    fork #10 survivor = 1; join_none
    fork disable fork; join
    #20;
    if (!survivor) $fatal(1, "singleton join disabled its sibling");

    survivor = 0;
    fork #10 survivor = 1; join_none
    fork disable fork; join_any
    #20;
    if (!survivor) $fatal(1, "singleton join_any disabled its sibling");
    // Suspending the singleton worker must leave its caller independently
    // waiting on join; resuming after the delay expires completes both.
    fork
      begin
        caller = process::self();
        fork begin worker = process::self(); #2 ran = 1; end join
        joined = 1;
      end
      begin
        wait (worker != null);
        #1 worker.suspend();
        #3;
        if (ran || joined) $fatal(1, "suspended singleton continued");
        worker.resume();
      end
    join
    if (worker == caller || !ran || !joined)
      $fatal(1, "singleton resume lost process boundary");

    // Killing the child releases join without killing its caller.
    worker = null;
    ran = 0;
    joined = 0;
    fork
      begin
        caller = process::self();
        fork begin worker = process::self(); #10 ran = 1; end join
        joined = 1;
      end
      begin
        wait (worker != null);
        #1 worker.kill();
      end
    join
    if (ran || !joined || worker.status() != process::KILLED)
      $fatal(1, "singleton kill affected caller");
    $display("PASSED");
  end
endmodule
