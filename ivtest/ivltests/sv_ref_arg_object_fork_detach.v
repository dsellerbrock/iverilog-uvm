// R25 (SILENT WRONG VALUE): an OBJECT-typed (class-handle) `ref' formal
// written from a `fork ... join_none' branch after the task itself
// returns lost the write, with no diagnostic.
//
//   task automatic spawn(ref process out_p);
//     fork begin out_p = process::self(); #4; end join_none
//   endtask
//   initial begin
//     spawn(gp);
//     #1 $display(gp == null);   // printed 1 (null) -- should be 0
//     #5 $display(gp == null);   // printed 1 (null) -- should be 0
//   end
//
// IEEE 1800-2017 13.5.2: "A reference to the original argument is passed
// to the subroutine" -- out_p IS gp, under another name, for as long as
// anything can still reach out_p through the binding. A `ref' formal was
// bound as a REAL reference (`.ref' / `%ref/bind') only for packed
// integral formals; a class-handle formal kept the legacy copy-in/
// copy-out pair. The copy-out ran when spawn() itself returned -- which
// happens at time 0, since spawn's own body is just the fork statement
// -- before the detached branch had written anything. The branch's
// later write landed in the copy-out's dead copy: nobody was watching
// it, and gp itself was never touched again.
//
// A class-handle `ref' formal is now bound like an integral one, so the
// write lands in the caller's variable whenever the branch executes, no
// matter how long it outlives the call.
//
// R25 stretch (CLOSED for TASK real formals): a `ref real' formal of a
// TASK is now bound the same way -- real reads/writes already went
// through the exact same generic interfaces the class-handle case uses
// (vvp_signal_value::real_value(), vvp_net_fun_t::recv_real()), so no
// new forwarding logic was needed in the delegating functor itself. Two
// runtime gaps had to close first, both now fixed (vvp/tgt-vvp):
//   1. `vvp_ref_signal_aa`'s VPI handle was always built as an INTEGER
//      wrapper (`vpip_make_int2`); reading a bound real through it
//      called `value_size()`/`value()`, which a real functor never
//      implements (there is no meaningful width or bit for a real) --
//      crash. A new `.ref/real` declaration (compile_ref_variable_real,
//      vvp/words.cc) attaches the real-flavored VPI wrapper instead, so
//      reads reach `get_signal_value()`/`real_value()`, which were
//      already correct.
//   2. Deliberately NOT extended to FUNCTIONS: a function's `ref`
//      argument binds through a wholly different mechanism
//      (tgt-vvp/draw_ufunc.c's per-argument codegen, not the
//      `$ivl_ref_bind` system task tasks use) whose companion fallback
//      for an actual that cannot be named directly hardcodes a vec4
//      store regardless of type -- a PRE-EXISTING, independent defect,
//      confirmed still present today for a class-handle FUNCTION formal
//      too (an automatic non-void function with a `ref` class-handle
//      formal called with an array-element actual crashes vvp with
//      "recv_vec4 not implemented"). Binding a FUNCTION's real formal
//      here would hit that same wall, so `ref_formal_is_bound()` grants
//      it to TASK scope only; a FUNCTION's real ref formal keeps the
//      copy pair, unchanged, exactly as it did before this fix (see
//      `rset` in sv_ref_argument_is_a_reference, a function, still
//      passing on the copy pair).
//
// String and container (dynamic array, queue, fixed array) formals
// still take the copy pair on TASKS too -- their reads and writes go
// through a type-specific opcode (%load/str, the container element/word
// ops) a bound formal cannot answer -- and are exercised below as
// controls to pin that the still-open gap for them is unchanged, not
// worse. R25 also asks that the hazard be made LOUD AT ELABORATION for
// exactly this residual shape (a copy-bound real/string/container `ref'
// formal on a task whose body forks a detached branch, IEEE 1800-2017
// 13.5.2): spawn_str/spawn_q below are EXPECTED TO WARN at compile time
// (spawn_real is not, now that its formal is bound). This test is
// registered WITH a gold file (ivtest/gold/sv_ref_arg_object_fork_detach.gold)
// that pins the exact two warning lines in the compile log, so the
// warning text and the fact that real no longer warns are both checked
// on every run, not just eyeballed once.

module main;

  int fails = 0;

  task chk_int(string what, int got, int want);
    if (got !== want) begin
      fails++;
      $display("FAILED -- %s: got %0d want %0d", what, got, want);
    end
  endtask

  task chk_real(string what, real got, real want);
    if (got != want) begin
      fails++;
      $display("FAILED -- %s: got %f want %f", what, got, want);
    end
  endtask

  // ------------------------------------------------------------------
  // 1. The reported defect, verbatim: a built-in `process' handle
  //    written by a detached fork branch after the spawning task
  //    itself has already returned.
  // ------------------------------------------------------------------
  process gp;
  task automatic spawn(ref process out_p);
    fork begin out_p = process::self(); #4; end join_none
  endtask

  // ------------------------------------------------------------------
  // 2. The same shape with a user class, and a check that what lands
  //    is the SAME object (identity), not merely a non-null one.
  // ------------------------------------------------------------------
  class Foo;
    int tag;
    function new(int t); tag = t; endfunction
  endclass

  Foo captured;
  Foo made_ref;   // the object the branch actually constructs

  task automatic spawn_user(ref Foo out_h);
    fork begin
      made_ref = new(99);
      out_h = made_ref;
      #4;
    end join_none
  endtask

  // ------------------------------------------------------------------
  // 3. Plain synchronous writes through a class-handle ref formal (no
  //    fork at all) must keep working -- this is the common case and
  //    must not regress.
  // ------------------------------------------------------------------
  Foo gh;
  task automatic set_it(ref Foo out_h, input int val);
    out_h = new(val);
  endtask
  task automatic clear_it(ref Foo out_h);
    out_h = null;
  endtask

  // ------------------------------------------------------------------
  // 4. An actual that cannot be named directly (an array element, a
  //    class property) binds to a per-frame companion object variable
  //    and is copied in/out through it, same as an integral ref formal.
  //    Concurrent calls each need their own companion.
  // ------------------------------------------------------------------
  Foo arr[3];
  class Holder;
    Foo h;
  endclass
  Holder hd;

  task automatic tag_elem(ref Foo out_h, input int val);
    repeat (3) #1;
    out_h = new(val);
  endtask

  // ------------------------------------------------------------------
  // 5. A ref formal of a static-lifetime task keeps the copy pair (no
  //    frame to bind into); a synchronous call must still work.
  // ------------------------------------------------------------------
  task st_task(ref Foo out_h);
    out_h = new(123);
  endtask

  // ------------------------------------------------------------------
  // 6. R25 stretch, CLOSED: a TASK's `ref real' formal is now bound, so
  //    a detached branch's write survives the task's own return, the
  //    same as the class-handle case above. Also exercised: a plain
  //    synchronous write, an unnameable actual (array element -- the
  //    front end's own companion-temporary path, independent of the
  //    vvp_ref_signal_aa binding proper), and a RECURSIVE call chaining
  //    a ref formal into itself -- the shape that exposed the runtime
  //    gap this fix had to close (a bound real formal's own VPI handle
  //    was built as an integer wrapper, so reading it crashed; see the
  //    header comment).
  // ------------------------------------------------------------------
  real gr;
  task automatic spawn_real(ref real out_r);
    fork begin out_r = 3.5; #4; end join_none
  endtask

  real gh_r;
  task automatic set_real(ref real out_r, input real val);
    out_r = val;
  endtask

  real rarr[3];
  task automatic tag_real_elem(ref real out_r, input real val);
    repeat (3) #1;
    out_r = val;
  endtask

  real racc;
  task automatic count_down_real(ref real acc, input int n);
    if (n <= 0) return;
    acc = acc + n;
    count_down_real(acc, n-1);
  endtask

  // ------------------------------------------------------------------
  // controls: types that still take the copy pair, in the SAME
  // fork/join_none-after-return shape as the defect. These are
  // expected to still show the pre-existing hazard -- unchanged, not
  // worse -- because their reads/writes go through a type-specific
  // opcode a bound formal cannot answer.
  // ------------------------------------------------------------------
  string gs;
  task automatic spawn_str(ref string out_s);
    fork begin out_s = "hello"; #4; end join_none
  endtask

  int gq[$];
  task automatic spawn_q(ref int out_q[$]);
    fork begin out_q.push_back(1); #4; end join_none
  endtask

  initial begin

    // ---- 1. the reported defect ----
    spawn(gp);
    #1;
    chk_int("built-in process ref, mid-window", gp == null, 0);
    #5;
    chk_int("built-in process ref, after the branch completes", gp == null, 0);

    // ---- 2. a user class, and object identity ----
    spawn_user(captured);
    #1;
    chk_int("user class ref, mid-window: not null", captured == null, 0);
    if (captured != made_ref) begin
      fails++;
      $display("FAILED -- user class ref: caller sees a different object than the branch made");
    end
    #5;
    chk_int("user class ref, after the branch completes", captured == null, 0);

    // ---- 3. plain synchronous writes ----
    set_it(gh, 7);
    chk_int("synchronous ref write: not null", gh == null, 0);
    chk_int("synchronous ref write: value", gh.tag, 7);
    clear_it(gh);
    chk_int("synchronous ref write: null again", gh == null, 1);

    // ---- 4. companion temporary: array element, class property ----
    hd = new;
    set_it(arr[1], 11);
    chk_int("array element actual: value", arr[1].tag, 11);
    chk_int("neighbour untouched", arr[0] == null, 1);
    set_it(hd.h, 22);
    chk_int("class property actual: value", hd.h.tag, 22);

    // concurrent calls through the temporary must not cross-contaminate
    fork tag_elem(arr[0], 100); join_none
    fork tag_elem(arr[2], 200); join_none
    #4;
    chk_int("concurrent companions: arr[0]", arr[0].tag, 100);
    chk_int("concurrent companions: arr[2]", arr[2].tag, 200);

    // ---- 5. a static-lifetime task's ref formal ----
    st_task(gh);
    chk_int("static-lifetime task ref: not null", gh == null, 0);
    chk_int("static-lifetime task ref: value", gh.tag, 123);

    // ---- 6. R25 stretch, CLOSED: a TASK's `ref real' formal ----
    fork spawn_real(gr); join_none
    #6;
    chk_real("real ref, detached branch write survives the return", gr, 3.5);

    set_real(gh_r, 9.25);
    chk_real("real ref: synchronous write", gh_r, 9.25);

    rarr[0] = 0.0; rarr[1] = 0.0; rarr[2] = 0.0;
    fork tag_real_elem(rarr[0], 100.0); join_none
    fork tag_real_elem(rarr[2], 200.0); join_none
    #4;
    chk_real("real ref: concurrent companion rarr[0]", rarr[0], 100.0);
    chk_real("real ref: concurrent companion rarr[2]", rarr[2], 200.0);
    chk_real("real ref: neighbour untouched rarr[1]", rarr[1], 0.0);

    racc = 0.0;
    count_down_real(racc, 4);
    chk_real("real ref: recursive chained binding", racc, 10.0);

    // ---- controls: the still-open gap, pinned unchanged ----
    fork spawn_str(gs); join_none
    fork spawn_q(gq); join_none
    #6;
    if (gs == "hello")
      $display("NOTE: ref string now also survives a detached branch (gap closed; update this control).");
    if (gq.size() != 0)
      $display("NOTE: ref queue now also survives a detached branch (gap closed; update this control).");

    if (fails == 0) $display("PASSED");
    else            $display("FAILED (%0d)", fails);
    $finish(0);
  end

endmodule
