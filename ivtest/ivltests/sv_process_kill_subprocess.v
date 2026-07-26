// IEEE 1800-2017 9.7.2: `kill()' terminates the process it is called on
// AND every sub-process that process spawned -- "terminates the given
// process and all its sub-processes, that is, processes spawned using
// fork statements by the process being killed".
//
// Only the JOINED children were being killed. The runtime unwinds the
// set a `%join' is waiting on, and a `fork ... join_none' child is
// DETACHED: it is never joined, so it lives in a separate set that the
// unwind never reached. Killing a parent left its join_none children
// running -- still advancing counters, still scheduling events, still
// reporting a live status -- with no diagnostic, because kill() returned
// normally and the parent itself really was dead.
//
// That is the shape UVM uses everywhere: a component forks a
// join_none worker and later kills the process handle to stop it. The
// worker kept running.
//
// A directly-killed sub-process always worked, so the control below
// passes with or without the fix; what distinguishes them is whether the
// counter freezes when the PARENT is the one killed.
//
// Each case samples its counter at the kill and again ten ticks later.
// A killed subtree must not have moved.

module main;

  int  gc = 0,  gcs;          // grandchild, two join_none levels down
  int  d1 = 0,  d1s;          // two detached children of one parent
  int  d2 = 0,  d2s;
  int  nz = 0,  nzs;          // control: a process with no sub-processes
  int  jn = 0,  jns;          // a join-style (attached) child
  int  ctl = 0, ctls;         // control: killed directly, not via a parent
  int  surv = 0;              // must KEEP running: an unrelated process

  process pg, pm, pd, pj, pc;

  int fails = 0;

  task chk_frozen(string what, int now, int at_kill);
    if (now !== at_kill) begin
      fails++;
      $display("FAILED -- %s survived the kill: %0d -> %0d", what, at_kill, now);
    end
  endtask

  initial begin

    // 1. a grandchild two join_none levels down: the walk has to recurse
    fork begin
      pg = process::self();
      fork begin
        fork forever #1 gc++; join_none
        #99;
      end join_none
      #99;
    end join_none

    // 2. a parent with TWO detached children: the walk has to drain the
    //    whole set, not just its first element
    fork begin
      pm = process::self();
      fork forever #1 d1++; join_none
      fork forever #1 d2++; join_none
      #99;
    end join_none

    // 3. control: a process with no sub-processes at all
    fork begin
      pd = process::self();
      forever #1 nz++;
    end join_none

    // 4. an ATTACHED child -- fork/join_any leaves the parent waiting on
    //    it, so this is the path that already worked. Kept as a control
    //    so a fix that broke it shows up here.
    fork begin
      pj = process::self();
      fork
        forever #1 jn++;
        #99;
      join_any
      #99;
    end join_none

    // 5. control: killing a sub-process handle directly
    fork begin
      fork begin
        pc = process::self();
        forever #1 ctl++;
      end join_none
      #99;
    end join_none

    // 6. an unrelated process: kill() must not touch it
    fork forever #1 surv++; join_none

    #5;
    pg.kill();
    pm.kill();
    pd.kill();
    pj.kill();
    pc.kill();

    gcs = gc; d1s = d1; d2s = d2; nzs = nz; jns = jn; ctls = ctl;
    #10;

    chk_frozen("the grandchild of a killed process", gc, gcs);
    chk_frozen("detached child 1 of a killed process", d1, d1s);
    chk_frozen("detached child 2 of a killed process", d2, d2s);
    chk_frozen("a childless killed process", nz, nzs);
    chk_frozen("the attached child of a killed process", jn, jns);
    chk_frozen("a directly killed sub-process", ctl, ctls);

    // The other half of 9.7.2: kill() kills the subtree, and nothing else.
    if (surv <= 5) begin
      fails++;
      $display("FAILED -- an unrelated process was killed too: %0d", surv);
    end

    // A killed process reports KILLED (9.7, Table 9-2).
    if (pg.status() != process::KILLED) begin
      fails++;
      $display("FAILED -- a killed process reports status %0d, want KILLED",
               pg.status());
    end

    if (fails == 0) $display("PASSED");
    else            $display("FAILED (%0d)", fails);
    $finish(0);
  end

endmodule
