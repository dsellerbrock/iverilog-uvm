// Process-identity semantics (IEEE 1800-2017 9.7): regression for the
// uninitialized vthread is_fork_v_child flag (gap G67).  A thread
// created by fork...join_none is its OWN process: process::self()
// inside the forked block must not resolve to the caller's process,
// and kill() on that handle must terminate only the forked block.
// With the flag left as heap garbage, process::self() inside a
// fork...join_none block could walk up to an ancestor process, so a
// later kill() of the "watcher" destroyed the whole calling chain
// (observed as the UVM sequencer handshake deadlock in vif_smoke).
class worker;
  process watcher_proc;
  process caller_proc;
  int watcher_started = 0;
  int watcher_killed_side_effect = 0;
  int survived = 0;

  // Mirrors uvm_sequencer_param_base::m_safe_select_item: fork a
  // watcher, capture its process handle, kill it, then keep going.
  task run(output int ok);
    caller_proc = process::self();
    fork
      begin
        watcher_proc = process::self();
        watcher_started = 1;
        #100;                       // would run long if never killed
        watcher_killed_side_effect = 1;
      end
    join_none
    wait (watcher_proc != null);

    if (watcher_proc == caller_proc) begin
      $display("FAIL m6proc: watcher process aliases caller process");
      ok = 0;
      return;
    end

    watcher_proc.kill();
    // The caller must survive the kill of its forked child: reaching
    // the statements below IS the check that failed under G67.
    survived = 1;
    #1;
    if (watcher_killed_side_effect) begin
      $display("FAIL m6proc: watcher survived kill()");
      ok = 0;
      return;
    end
    ok = 1;
  endtask
endclass

module m6_process_identity_test;
  worker w;
  int ok = 0;
  int done = 0;

  initial begin
    w = new;
    w.run(ok);
    done = 1;
    if (ok && w.survived) $display("PASS");
    else $display("FAIL m6proc ok=%0d survived=%0d", ok, w.survived);
    $finish;
  end

  initial begin
    #50;
    if (!done) $display("FAIL m6proc (hang: caller chain was killed)");
    $finish;
  end
endmodule
