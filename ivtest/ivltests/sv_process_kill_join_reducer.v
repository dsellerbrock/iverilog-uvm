// Reducer for the UVM process-guard self-kill path. The nested functions are
// synchronous frames of the same logical process, not subprocesses. IEEE 1800
// 9.7.2 process::kill() terminates that process from the point of the call; the
// runtime must unwind already-reaped call frames instead of joining them again.

module main;
  process guarded_process;
  process static_guarded_process;
  int values[1];
  int static_values[1];
  int index_calls;
  int static_index_calls;

  function automatic int copy_index();
    index_calls++;
    // An inout element index is evaluated once for copy-in and again for
    // copy-out. On the second evaluation, update_value() has returned but its
    // caller-owned automatic frame still awaits the generated %free.
    if (index_calls == 2)
      guarded_process.kill();
    return 0;
  endfunction

  function automatic void update_value(inout int value);
    value++;
  endfunction

  function automatic void clear_guard();
    // The outer %alloc precedes the first copy_index() evaluation. That nested
    // call overwrites the single fork-handoff marker; the runtime must still
    // retain exact ownership of update_value() through its second, copy-out
    // index evaluation and the process self-kill there.
    update_value(values[copy_index()]);
    $display("FAILED: caller continued after self-kill");
    $finish(1);
  endfunction

  function int static_copy_index();
    static_index_calls++;
    if (static_index_calls == 2)
      static_guarded_process.kill();
    return 0;
  endfunction

  function automatic void update_static_value(inout int value);
    value++;
  endfunction

  function automatic void clear_static_guard();
    // The copy-out index call itself has no automatic frame. Killing there
    // must still release the completed update_static_value() record below it.
    update_static_value(static_values[static_copy_index()]);
    $display("FAILED: static-index caller continued after self-kill");
    $finish(1);
  endfunction

  initial begin : guarded
    guarded_process = process::self();
    values[0] = 41;
    index_calls = 0;
    clear_guard();
    $display("FAILED: process root continued after self-kill");
    $finish(1);
  end

  initial begin : static_guarded
    static_guarded_process = process::self();
    static_values[0] = 9;
    static_index_calls = 0;
    clear_static_guard();
    $display("FAILED: static-index process root continued after self-kill");
    $finish(1);
  end

  initial begin : observer
    #1;
    $display("PASSED");
    $finish(0);
  end
endmodule
