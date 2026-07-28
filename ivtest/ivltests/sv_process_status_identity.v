// process::self() must name the CALLING process, and status() must
// report that process's live state (IEEE 1800-2017 9.7).
//
// Both were broken, together, and silently:
//
//   - status() returned WAITING (2) for every process, in every state:
//     for the caller itself, for a branch that had finished, for one
//     that was blocked, and for one that had been woken and ended. A
//     constant function wearing an API's name.
//
//   - self() inside every branch of an ordinary fork..join_none
//     returned the SAME handle -- the enclosing process's -- so the
//     branches' own identities were unreachable. status/suspend/kill
//     aimed at a branch handle silently aimed at the parent.
//
// The two had one root. An anonymous fork branch is compiled with its
// ENCLOSING scope, and the runtime classified "is this thread its own
// process?" by scope TYPE: vpiTask and vpiNamedBegin meant "no, walk
// up" (correct for task calls and frame-owning begin blocks, which are
// the same process as their caller). A branch spawned inside an initial
// block with declarations wears that begin block's vpiNamedBegin scope;
// a branch inside a task body wears vpiTask. Both walked up. The code
// generator knows which construct it is emitting, so a true branch now
// arrives through its own instruction (%fork/p) and keeps its identity.
//
// The WAITING half: a process is its root thread plus the synchronous
// frames it executes through -- a begin-with-declarations body runs in
// a child vthread while the root parks in %join. status() consulted
// only the root, and a parked root reads as waiting, so a process whose
// statements were ALL busily executing reported WAITING -- including to
// itself. status() now recognises the currently-executing thread as
// part of the process.

module main;

  int fails = 0;

  task chk(string what, int got, int want);
    if (got !== want) begin
      fails++;
      $display("FAILED -- %s: got %0d want %0d", what, got, want);
    end
  endtask

  // A fork branch inside a TASK body: the branch wears the task's
  // scope, which is the shape the scope-type heuristic got most wrong.
  // The branch writes the module-scope variable directly. (Writing it
  // through a `ref' formal is a DIFFERENT known residual: an
  // object-typed ref takes the copy-in/copy-out fallback, whose
  // copy-out runs when the task returns -- a join_none branch writing
  // the formal afterwards updates a dead copy, silently. See R25.)
  process task_branch_p;
  task automatic spawn_from_task();
    fork begin
      task_branch_p = process::self();
      #4;
    end join_none
  endtask

  event ev;
  process sp, sp2, pf, pw, ptask_caller;

  initial begin
    // ---- self() is the calling process, and it is RUNNING ----
    sp = process::self();
    chk("self() non-null",              sp == null ? 1 : 0, 0);
    chk("own status is RUNNING",        sp.status(), process::RUNNING);

    // the same process asking twice gets the same identity
    sp2 = process::self();
    chk("self() is stable",             sp2 == sp ? 1 : 0, 1);

    // ---- each branch is its OWN process ----
    fork begin pf = process::self(); end join_none
    fork begin pw = process::self(); @ev; end join_none
    #1;
    chk("branch handle differs from parent", pf == sp ? 1 : 0, 0);
    chk("branches differ from each other",   pf == pw ? 1 : 0, 0);

    // ---- status() tracks the life cycle ----
    chk("finished branch is FINISHED",  pf.status(), process::FINISHED);
    chk("blocked branch is WAITING",    pw.status(), process::WAITING);
    -> ev; #1;
    chk("woken branch is FINISHED",     pw.status(), process::FINISHED);

    // ---- a branch spawned inside a task body ----
    ptask_caller = process::self();
    spawn_from_task();
    #1;
    chk("task-spawned branch has its own identity",
        task_branch_p == ptask_caller ? 1 : 0, 0);
    chk("and it is alive on its own clock",
        task_branch_p.status() == process::FINISHED ? 1 : 0, 0);
    #5;
    chk("and finishes on its own clock",
        task_branch_p.status(), process::FINISHED);

    // ---- control: a named begin/end is NOT a process (9.3.1) ----
    begin : named_blk
      automatic process inner = process::self();
      chk("self() in a named block is the enclosing process",
          inner == sp ? 1 : 0, 1);
    end

    // ---- control: suspend/resume still lands on the right thread ----
    begin
      process victim;
      automatic int progress = 0;
      fork begin victim = process::self(); #2 progress = 1; #2 progress = 2; end join_none
      #1;                       // victim is inside its first delay
      victim.suspend();
      #4;                       // both delays would have elapsed
      chk("suspended branch made no progress", progress, 0);
      chk("suspended branch reports SUSPENDED", victim.status(),
          process::SUSPENDED);
      victim.resume();
      #5;
      chk("resumed branch completed", progress, 2);
      chk("resumed branch is FINISHED", victim.status(), process::FINISHED);
    end

    // ---- control: kill on a branch handle kills that branch only ----
    begin
      process doomed, bystander;
      automatic int d_ran = 0, b_ran = 0;
      fork begin doomed = process::self(); #2 d_ran = 1; end join_none
      fork begin bystander = process::self(); #3 b_ran = 1; end join_none
      #1 doomed.kill();
      #4;
      chk("killed branch did not run on",  d_ran, 0);
      chk("killed branch reports KILLED",  doomed.status(), process::KILLED);
      chk("its sibling was untouched",     b_ran, 1);
    end

    if (fails == 0) $display("PASSED");
    else            $display("FAILED (%0d)", fails);
    $finish(0);
  end

endmodule
