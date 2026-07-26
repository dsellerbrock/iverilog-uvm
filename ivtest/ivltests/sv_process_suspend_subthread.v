// IEEE 1800-2017 9.7.2: `suspend()' stops the process it names, and
// `resume()' restarts it where it left off.
//
// A named begin/end body and a synchronous task frame each execute in
// their own runtime thread, but they are NOT sub-processes -- they are
// the same process, which is why `process::self()' called inside one
// returns the enclosing fork thread. While such a body runs, the thread
// the handle names is parked waiting for it. Marking only that thread
// suspended therefore suspended nothing: the process kept counting time,
// kept scheduling events, and `status()' answered SUSPENDED the whole
// while -- a wrong value with no diagnostic behind it.
//
// A process whose body is a plain statement list has no such inner
// thread, which is why that shape always worked and is the control here.
//
// The same shape could also abort the runtime outright: suspending a
// process blocked inside a synchronous task frame left the frame running
// with its parent already parked, and the parent's `end' then tripped an
// assertion that its child set was empty.
//
// `kill()' cascades to sub-processes; 9.7.2 gives that cascade to kill()
// alone, so a `fork ... join_none' child of a suspended process must
// keep running. That direction is checked too -- a fix that suspended
// the world would pass every other case here.

module main;

  int plain = 0,  plain_s;      // control: no inner thread
  int named = 0,  named_s;      // blocked inside a named begin/end
  int deep  = 0,  deep_s;       // two levels of named block
  int frame = 0,  frame_s;      // blocked inside a task frame
  int mixed = 0,  mixed_s;      // a named block containing a task call
  int selfsp = 0, selfsp_s;     // suspends itself from inside a named block
  int sub   = 0,  sub_s;        // a join_none SUB-process: must keep going

  process p_plain, p_named, p_deep, p_frame, p_mixed, p_self, p_sub;

  int fails = 0;

  task automatic spin_frame();
    forever #1 frame++;
  endtask

  task automatic spin_mixed();
    forever #1 mixed++;
  endtask

  task chk_stopped(string what, int now, int at_suspend);
    if (now !== at_suspend) begin
      fails++;
      $display("FAILED -- %s kept running while suspended: %0d -> %0d",
               what, at_suspend, now);
    end
  endtask

  task chk_resumed(string what, int now, int at_resume);
    if (now === at_resume) begin
      fails++;
      $display("FAILED -- %s never restarted after resume(): stuck at %0d",
               what, now);
    end
  endtask

  task chk_status(string what, int got);
    if (got !== 3) begin           // process::SUSPENDED
      fails++;
      $display("FAILED -- %s reports status %0d, want SUSPENDED(3)", what, got);
    end
  endtask

  initial begin

    fork begin
      p_plain = process::self();
      forever #1 plain++;
    end join_none

    fork begin
      p_named = process::self();
      begin : nb
        forever #1 named++;
      end
    end join_none

    fork begin
      p_deep = process::self();
      begin : d1
        begin : d2
          forever #1 deep++;
        end
      end
    end join_none

    fork begin
      p_frame = process::self();
      spin_frame();
    end join_none

    fork begin
      p_mixed = process::self();
      begin : mb
        spin_mixed();
      end
    end join_none

    fork begin
      p_self = process::self();
      begin : sb
        #2;
        p_self.suspend();          // takes effect immediately (9.7.2)
        forever #1 selfsp++;
      end
    end join_none

    fork begin
      p_sub = process::self();
      fork forever #1 sub++; join_none
      #99;
    end join_none

    #5;
    p_plain.suspend();
    p_named.suspend();
    p_deep.suspend();
    p_frame.suspend();
    p_mixed.suspend();
    p_sub.suspend();
    // p_self suspended itself at t=2.

    plain_s = plain; named_s = named; deep_s = deep;
    frame_s = frame; mixed_s = mixed; selfsp_s = selfsp; sub_s = sub;
    #10;

    chk_stopped("a plain process body",              plain,  plain_s);
    chk_stopped("a named begin/end body",            named,  named_s);
    chk_stopped("a nested named begin/end body",     deep,   deep_s);
    chk_stopped("a task frame",                      frame,  frame_s);
    chk_stopped("a task frame inside a named block", mixed,  mixed_s);
    chk_stopped("a self-suspended named block",      selfsp, selfsp_s);

    // The other direction: 9.7.2 cascades to sub-processes for kill()
    // only, so this one must NOT have stopped.
    if (sub === sub_s) begin
      fails++;
      $display("FAILED -- a join_none sub-process was suspended with its parent");
    end

    chk_status("a suspended plain process",   p_plain.status());
    chk_status("a suspended named block",     p_named.status());
    chk_status("a suspended task frame",      p_frame.status());
    chk_status("a self-suspended process",    p_self.status());

    plain_s = plain; named_s = named; deep_s = deep;
    frame_s = frame; mixed_s = mixed; selfsp_s = selfsp;

    p_plain.resume();
    p_named.resume();
    p_deep.resume();
    p_frame.resume();
    p_mixed.resume();
    p_self.resume();
    p_sub.resume();
    #10;

    chk_resumed("a plain process body",              plain,  plain_s);
    chk_resumed("a named begin/end body",            named,  named_s);
    chk_resumed("a nested named begin/end body",     deep,   deep_s);
    chk_resumed("a task frame",                      frame,  frame_s);
    chk_resumed("a task frame inside a named block", mixed,  mixed_s);
    chk_resumed("a self-suspended named block",      selfsp, selfsp_s);

    if (fails == 0) $display("PASSED");
    else            $display("FAILED (%0d)", fails);
    $finish(0);
  end

endmodule
