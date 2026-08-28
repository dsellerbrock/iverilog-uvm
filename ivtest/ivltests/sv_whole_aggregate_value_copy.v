// Whole-aggregate value copies in the CONTAINER -> FIXED ARRAY
// direction (IEEE 1800-2017 7.6 assignment, 13.5.2 subroutine
// copy-back).
//
// The other direction has worked since M10-1: a fixed unpacked array
// used where a dynamic array or queue is wanted marshals its words into
// container storage (%load/arr/dar). Coming back was missing entirely,
// and it failed differently everywhere it appeared:
//
//   int fa[3];  int da[];  da = new[3];
//   fa = da;              // silently assigned the CONSTANT 0
//
//   task t(inout int q[]);  ...  endtask
//   t(fa);                // ivl: stmt_assign.c:733: store_vec4_to_lval:
//                         //   Assertion `lwid == ivl_signal_width(lsig)'
//                         //   failed.  -- an abort on legal input, and
//                         //   it aborted even when the body only READ
//                         //   the formal, because the copy-out is
//                         //   generated from the port direction alone
//
//   function int f(ref int q[]);  ...  endfunction
//   r = f(fa);            // "Skipping unsupported function copy-out
//                         //  argument" once, then silence; the caller's
//                         //  array never changed
//
// The assignment case is the worst of the three. `fa = da' is not
// type_compatible -- one side is a container object, the other is inline
// words -- so it reached a compile-progress fallback in elab_and_eval
// that replaces an incompatible right-hand side with a constant when the
// target looks vectorable. An unpacked array's `cast_type' is its
// ELEMENT type, so `int fa[3]' looked exactly that vectorable, and the
// whole right-hand side became 32'd0. No diagnostic, and the array was
// zeroed rather than copied.
//
// All three are now one copy: %store/arr/dar, the inverse of the
// instruction the outbound direction already used. Element counts can
// only be compared at run time for a dynamic source, so that check lives
// in the instruction (the mismatch case is checked in
// sv_whole_aggregate_size_mismatch).

module main;

  typedef struct { int arr[3]; int tag; } S;
  typedef struct { int arr[3]; } Inner;

  class C;
    int arr[3];
  endclass

  int   fa[3];
  int   desc[2:0];
  byte  ba[3];
  logic [7:0] la[3];
  real  ra[3];
  int   da[];
  int   qu[$];
  S     s;
  Inner sa[2];
  C     c;

  int fails = 0;

  task chk(string what, int got, int want);
    if (got !== want) begin
      fails++;
      $display("FAILED -- %s: got %0d want %0d", what, got, want);
    end
  endtask

  // ---- the subroutine forms ----
  task automatic bump_t(inout int q[]);
    foreach (q[i]) q[i] = q[i] + 100;
  endtask

  task automatic read_only_t(inout int q[]);
    // Writes nothing. The copy-out is still generated, and this is the
    // shape that aborted ivl even though nothing was modified.
    if (q[0] == -12345) $display("unreachable");
  endtask

  task automatic ref_t(ref int q[]);
    foreach (q[i]) q[i] = q[i] + 100;
  endtask

  task automatic queue_formal_t(inout int q[$]);
    foreach (q[i]) q[i] = q[i] + 100;
  endtask

  task automatic byte_t(inout byte q[]);
    foreach (q[i]) q[i] = q[i] + 8'd10;
  endtask

  task automatic vec_t(inout logic [7:0] q[]);
    foreach (q[i]) q[i] = q[i] + 8'd10;
  endtask

  task automatic real_t(inout real q[]);
    foreach (q[i]) q[i] = q[i] + 1.5;
  endtask

  task automatic whole_assign_t(inout int q[]);
    // Replaces the formal's value outright rather than element by
    // element; the copy-back must still deliver it.
    q = '{7, 8, 9};
  endtask

  function automatic int func_ref(ref int q[]);
    q[0] = 55;
    return q[1];
  endfunction

  // A fixed array actual is also legal as a plain input open array, and
  // that direction must keep working unchanged.
  function automatic int sum_in(input int q[]);
    int t = 0;
    foreach (q[i]) t += q[i];
    return t;
  endfunction

  initial begin
    // ================= 7.6 whole-array assignment =================
    da = new[3];
    da[0] = 10; da[1] = 20; da[2] = 30;
    qu = '{40, 50, 60};

    fa = da;
    chk("assign fixed <- dynamic [0]", fa[0], 10);
    chk("assign fixed <- dynamic [1]", fa[1], 20);
    chk("assign fixed <- dynamic [2]", fa[2], 30);

    fa = qu;
    chk("assign fixed <- queue [0]",   fa[0], 40);
    chk("assign fixed <- queue [2]",   fa[2], 60);

    // A descending declared range. IEEE 7.6 maps elements left-to-right:
    // dynamic element 0 corresponds to desc[2], not the numerically lowest
    // declared index. A copy out and back must still be exact.
    desc = da;
    chk("assign into a descending array [2]", desc[2], 10);
    chk("assign into a descending array [0]", desc[0], 30);
    begin
      int desc_back[2:0];
      desc[2] = 100; desc[1] = 200; desc[0] = 300;
      da = desc;
      desc_back = da;
      chk("descending round trip [2]", desc_back[2], 100);
      chk("descending round trip [1]", desc_back[1], 200);
      chk("descending round trip [0]", desc_back[0], 300);
      da = new[3];
      da[0] = 10; da[1] = 20; da[2] = 30;
    end

    // a struct member, with a neighbour that must not be touched
    s.tag = 77;
    s.arr = da;
    chk("assign struct member <- dynamic", s.arr[1], 20);
    chk("the member beside it is intact",  s.tag,    77);

    // an element of an array of structs
    sa[1].arr = qu;
    chk("assign array-of-structs member",  sa[1].arr[2], 60);

    // a class property
    c = new;
    c.arr = da;
    chk("assign class property <- dynamic", c.arr[0], 10);

    // ---- controls: the outbound direction and fixed<-fixed ----
    da = fa;
    chk("control: dynamic <- fixed size", da.size(), 3);
    chk("control: dynamic <- fixed [0]",  da[0],    40);
    qu = fa;
    chk("control: queue <- fixed size",   qu.size(), 3);

    begin
      int other[3];
      other = fa;
      chk("control: fixed <- fixed",      other[2], 60);
    end

    // ================= 13.5.2 subroutine copy-back =================
    fa = '{1, 2, 3};
    bump_t(fa);
    chk("task inout, element writes [0]", fa[0], 101);
    chk("task inout, element writes [2]", fa[2], 103);

    fa = '{1, 2, 3};
    read_only_t(fa);
    chk("task inout, body writes nothing [0]", fa[0], 1);
    chk("task inout, body writes nothing [2]", fa[2], 3);

    fa = '{1, 2, 3};
    ref_t(fa);
    chk("task ref",                       fa[1], 102);

    fa = '{1, 2, 3};
    whole_assign_t(fa);
    chk("task inout, whole-value write [0]", fa[0], 7);
    chk("task inout, whole-value write [2]", fa[2], 9);

    fa = '{1, 2, 3};
    queue_formal_t(fa);
    chk("queue formal, fixed actual",     fa[2], 103);

    ba = '{1, 2, 3};
    byte_t(ba);
    chk("a byte element type",            int'(ba[1]), 12);

    la = '{1, 2, 3};
    vec_t(la);
    chk("a packed-vector element type",   int'(la[2]), 13);

    fa = '{1, 2, 3};
    begin
      int r;
      r = func_ref(fa);
      chk("function ref, return value",   r,      2);
      chk("function ref, copy-back",      fa[0], 55);
    end

    // a struct member as the actual
    s.arr = '{1, 2, 3};
    s.tag = 77;
    bump_t(s.arr);
    chk("struct member as the actual",    s.arr[1], 102);
    chk("its neighbour is still intact",  s.tag,     77);

    // a class property as the actual
    c.arr = '{1, 2, 3};
    bump_t(c.arr);
    chk("class property as the actual",   c.arr[2], 103);

    // a dynamic-array actual keeps its by-handle behaviour
    da = new[3];
    da[0] = 1; da[1] = 2; da[2] = 3;
    bump_t(da);
    chk("control: a dynamic array actual", da[0], 101);

    // ---- control: an input open array is a copy, so the actual is
    //      NOT modified, and reading it still works ----
    fa = '{1, 2, 3};
    chk("control: input open array reads", sum_in(fa), 6);
    chk("control: input leaves the actual", fa[0],      1);

    // ---- real elements, both directions ----
    begin
      real rd[];
      rd = new[3];
      rd[0] = 1.0; rd[1] = 2.0; rd[2] = 3.0;
      ra = rd;
      if (ra[2] != 3.0) begin
        fails++;
        $display("FAILED -- assign a real fixed array <- dynamic: got %f", ra[2]);
      end
      real_t(ra);
      if (ra[0] != 2.5) begin
        fails++;
        $display("FAILED -- real element copy-back: got %f want 2.5", ra[0]);
      end
    end

    if (fails == 0) $display("PASSED");
    else            $display("FAILED (%0d)", fails);
    $finish(0);
  end

endmodule
