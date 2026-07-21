// A single-branch `fork task(<automatic>); join_none` re-executed each loop
// iteration must capture the argument value AT SPAWN (IEEE 1800-2017 9.3.2:
// each spawned process gets the automatic's value at the fork), not when
// the detached process is later scheduled.
//
// Inside a class method (an automatic scope), iverilog used to emit the
// whole wrapped call — %alloc of the callee frame, the argument stores, the
// call — inside the detached thread, so the stores ran when the thread was
// scheduled and read the LAST value the shared loop automatic held. Every
// forked worker therefore saw the final index. (At module scope the loop
// body already had a per-iteration frame, so this worked.)
//
// The fix hoists the callee %alloc + argument stores to run in the spawning
// thread, before the %fork. This test also checks that an OUTER automatic
// (a method argument / handle passed alongside the loop local) is still
// read correctly — the fix must not disturb single-task-frame access.
//
// Each worker records its captured index in a fixed slot (marks[idx]) and
// the captured outer handle name (names[idx]). PASSED only if every slot
// 0..N-1 was written exactly once, by a worker that also saw the shared
// outer handle.

module sv_fork_call_arg_capture;

  localparam int N = 5;

  class tag_t;
    string nm;
    function new(string s); nm = s; endfunction
  endclass

  class runner;
    int    marks [N];   // marks[idx] = idx+1 when the worker for idx runs
    string names [N];   // names[idx] = the outer handle name that worker saw

    task automatic worker(tag_t t, int idx);
      #1;
      marks[idx] = idx + 1;   // idx is the spawn-captured index
      names[idx] = t.nm;
    endtask

    task automatic run(tag_t shared);
      for (int i = 0; i < N; i++) begin
        automatic int idx = i;
        fork
          worker(shared, idx);
        join_none
      end
      #10;   // let all detached workers run
    endtask
  endclass

  int errors = 0;

  initial begin
    runner r = new;
    tag_t  tg = new("OUTER");

    r.run(tg);

    for (int j = 0; j < N; j++) begin
      if (r.marks[j] !== j + 1) begin
        $display("FAIL: slot %0d = %0d (want %0d) — worker did not capture index %0d",
                 j, r.marks[j], j + 1, j);
        errors++;
      end
      if (r.names[j] != "OUTER") begin
        $display("FAIL: slot %0d outer handle = '%s' (want OUTER)", j, r.names[j]);
        errors++;
      end
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
