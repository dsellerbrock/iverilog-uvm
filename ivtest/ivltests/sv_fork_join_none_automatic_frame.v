// An automatic local of a task invoked as `fork <task>(); join_none'
// read back as its initializer -- inside the task's own body, with no
// delay and no diagnostic. So did the arguments the call was given.
//
//     task automatic t();
//       int loc = 0;
//       loc++; loc++; loc++;
//       $display("%0d", loc);      // printed 0
//     endtask
//     initial fork t(); join_none
//
// Calling the same task directly printed 3.
//
// The cause is the spawn-time argument capture in the vvp code
// generator. For a SINGLE-branch join_none it hoists the child's
// leading `%alloc' and argument stores out of the detached thread and
// runs them in the spawning thread, so that
//
//     for (int i = 0; i < N; i++) fork worker(i); join_none
//
// snapshots the loop's automatic at spawn rather than reading it after
// the loop has moved on. That hoist emits
//
//     %alloc S_<callee>;          <- in the spawning thread
//     %fork t_1, S_<enclosing>;
//   t_1:
//     %fork TD_<callee>, S_<callee>;
//
// and the frame never arrived: the runtime handed a fork child the
// staged write context only when the CHILD's own scope was automatic,
// and the intermediate thread is forked into the enclosing scope, which
// is not. The callee therefore ran with no frame at all.
//
// The shape is narrow enough to have hidden: a `fork begin ... end
// join_none' with the body inline was always correct, and so was a
// forked call with copy-out work after it, because that keeps its
// %alloc inside the detached thread. Those are the controls below.
//
// The frame is now MOVED to the thread that will use it -- the spawning
// thread goes back to where it stood before the %alloc, since the
// matching %free belongs to the child. Sharing it instead would hand a
// later sibling a pointer to storage the child has already freed, which
// is the second case below: two forked calls in a row, the first of
// which must not disturb the second.

module main;

  int fails = 0;

  task chk(string what, int got, int want);
    if (got !== want) begin
      fails++;
      $display("FAILED -- %s: got %0d want %0d", what, got, want);
    end
  endtask

  // ---- the failing shape, in its smallest form ----
  int noargs_saw = -1;
  task automatic noargs();
    int loc = 0;
    loc++; loc++; loc++;
    noargs_saw = loc;
  endtask

  // ---- and with arguments, which were lost with it ----
  int arg_loc = -1, arg_in = -1;
  task automatic withargs(input int n);
    int loc = 0;
    loc++; loc++; loc++;
    arg_loc = loc;
    arg_in  = n;
  endtask

  // ---- a second forked call must not inherit the first one's frame ----
  int two_a = -1, two_b = -1;
  task automatic two(input int who);
    int loc = 0;
    repeat (3) #1 loc++;
    if (who == 1) two_a = loc; else two_b = loc;
  endtask

  // ---- controls: the shapes that always worked ----
  int inline_saw = -1;       // fork begin ... end join_none
  int copyout_saw = -1;      // a forked call with copy-out work after it
  task automatic withport(output int o);
    int loc = 0;
    loc++; loc++; loc++;
    o = loc;
  endtask

  // ---- the reason the hoist exists: a loop-carried automatic must be
  //      snapshotted at spawn, not read after the loop has moved on ----
  int seen [4];
  task automatic capture(input int i, input int v);
    seen[i] = v;
  endtask

  // ---- the spawner is itself an automatic frame ----
  //
  // Handing the frame over means the spawner has to be put back exactly
  // where it stood before the %alloc. When the spawner is the initial
  // block that is nowhere; when it is an automatic task or a class
  // method it is that subroutine's own frame, and getting it wrong
  // loses the spawner's locals rather than the callee's.
  int res [8];
  task automatic worker(input int slot, input int n);
    int loc = 0;
    repeat (n) #1 loc++;
    res[slot] = loc;
  endtask

  task automatic spawner(input int base);
    int mine = 100;
    fork worker(base,   2); join_none
    mine++;
    fork worker(base+1, 3); join_none
    mine++;
    #6;
    res[base+2] = mine;
  endtask

  class Spawner;
    int mine = 200;
    task automatic go(input int base);
      fork worker(base, 4); join_none
      mine++;
      #6;
      res[base+1] = mine;
    endtask
  endclass
  Spawner sp;

  initial begin
    fork noargs(); join_none
    fork withargs(42); join_none
    fork begin
      automatic int loc = 0;
      loc++; loc++; loc++;
      inline_saw = loc;
    end join_none
    fork withport(copyout_saw); join_none
    #1;

    chk("an automatic local of a forked zero-argument task", noargs_saw, 3);
    chk("an automatic local of a forked task with arguments", arg_loc, 3);
    chk("the argument that task was given",                  arg_in, 42);
    chk("control: fork begin ... end",                       inline_saw, 3);
    chk("control: a forked call with copy-out work",         copyout_saw, 3);

    // two in a row, both time-consuming, each with its own frame
    fork two(1); join_none
    fork two(2); join_none
    #6;
    chk("the first of two forked calls",  two_a, 3);
    chk("the second of two forked calls", two_b, 3);

    // the loop-snapshot the hoist was written for
    for (int i = 0; i < 4; i++) begin
      seen[i] = -1;
      fork capture(i, i * 10); join_none
    end
    #1;
    for (int i = 0; i < 4; i++)
      chk($sformatf("loop-carried automatic snapshotted at spawn [%0d]", i),
          seen[i], i * 10);

    // ---- spawners that carry frames of their own ----
    for (int i = 0; i < 8; i++) res[i] = -1;
    sp = new();
    fork spawner(0); join_none
    fork sp.go(4);   join_none
    #10;
    chk("a worker forked from an automatic-task spawner",   res[0], 2);
    chk("a second worker from that same spawner",           res[1], 3);
    chk("the spawner's own local survived the hand-off",    res[2], 102);
    chk("a worker forked from a class-method spawner",      res[4], 4);
    chk("that method's property survived the hand-off",     res[5], 201);

    if (fails == 0) $display("PASSED");
    else            $display("FAILED (%0d)", fails);
    $finish(0);
  end

endmodule
