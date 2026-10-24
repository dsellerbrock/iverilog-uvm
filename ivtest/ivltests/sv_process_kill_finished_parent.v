// IEEE 1800-2017/2023 9.7: kill() terminates a process's subprocesses,
// including when the parent process has already finished.
module main;
  process finished_parent, live_parent;
  int finished_ran, live_ran;

  initial begin
    fork
      begin
        finished_parent = process::self();
        fork
          begin #5; finished_ran = 1; end
        join_none
      end
      begin
        live_parent = process::self();
        fork
          begin #5; live_ran = 1; end
        join_none
        #20;
      end
    join_none

    wait (finished_parent != null && live_parent != null);
    wait (finished_parent.status() == process::FINISHED);
    finished_parent.kill();
    #1;
    live_parent.kill();
    #6;

    if (finished_ran != 0)
      $fatal(1, "descendant of finished process survived kill()");
    if (live_ran != 0)
      $fatal(1, "descendant of live process survived kill()");
    $display("PASSED");
    $finish(0);
  end
endmodule
