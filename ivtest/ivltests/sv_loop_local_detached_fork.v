// IEEE 1800-2017 9.3.2: each iteration of a loop creates a fresh copy of a
// block's automatic variables, and a detached (join_none) branch that
// captures such a variable by reference must observe that iteration's copy
// even when it runs after the iteration has completed.
//
// Inside a class method (an automatic task), the loop-body block that
// declares `automatic int idx = i` used to be collapsed into the single
// task activation frame, so every iteration shared one storage slot for
// idx. A detached fork reading idx after a delay then saw only the final
// value. At module scope the same block already kept a per-entry frame and
// behaved correctly, so the two contexts disagreed.
//
// This test checks the class-method context (the previously broken case),
// a nested detached fork inside a class method, and the module-scope
// context (which was already correct), all in one run. Each detached
// worker captures its iteration's idx and, after a delay, records it into
// a fixed per-index slot keyed by the captured value. Correct per-iteration
// capture fills every slot 0..N-1 exactly once; a stale single-slot capture
// leaves all but the last slot untouched.

module sv_loop_local_detached_fork;

  localparam int N = 6;

  class Worker;
    int seen[N];

    // Each worker sets seen[idx] = idx+1 (so 0 means "never captured this
    // index"). A correct run fills all N slots; a broken (stale) run fills
    // only the final index N-1.
    function automatic bit all_filled();
      for (int k = 0; k < N; k++)
        if (seen[k] !== k+1) return 1'b0;
      return 1'b1;
    endfunction

    task automatic run_flat();
      for (int k = 0; k < N; k++) seen[k] = 0;
      for (int i = 0; i < N; i++) begin
        automatic int idx = i;
        fork begin #1; seen[idx] = idx + 1; end join_none
      end
      #(2*N);
    endtask

    // The loop lives inside an outer detached fork; each iteration then
    // spawns its own inner detached fork that captures idx.
    task automatic run_nested();
      for (int k = 0; k < N; k++) seen[k] = 0;
      fork
        begin
          for (int i = 0; i < N; i++) begin
            automatic int idx = i;
            fork begin #1; seen[idx] = idx + 1; end join_none
            #1;
          end
        end
      join_none
      #(4*N);
    endtask
  endclass

  int mseen[N];
  int errors = 0;

  initial begin
    Worker w = new;

    // 1) class-method flat loop (previously broken: all slots but the last
    //    stayed 0 because idx was shared across iterations).
    w.run_flat();
    if (!w.all_filled()) begin
      $display("FAIL: class flat loop capture");
      errors++;
    end

    // 2) class-method nested detached fork.
    w.run_nested();
    if (!w.all_filled()) begin
      $display("FAIL: class nested detached fork capture");
      errors++;
    end

    // 3) module-scope loop (already correct — guards against regressing it).
    for (int k = 0; k < N; k++) mseen[k] = 0;
    for (int i = 0; i < N; i++) begin
      automatic int idx = i;
      fork begin #1; mseen[idx] = idx + 1; end join_none
    end
    #(2*N);
    for (int k = 0; k < N; k++)
      if (mseen[k] !== k+1) begin
        $display("FAIL: module-scope loop capture at %0d", k);
        errors++;
      end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
