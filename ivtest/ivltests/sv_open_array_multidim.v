// A MULTI-DIMENSIONAL fixed unpacked array as an open-array actual
// (IEEE 1800-2017 13.5.2, and H.10.2 for the per-dimension bounds).
//
// A 2-D struct MEMBER already worked: `%prop/arr/dar` materializes a
// nested container -- one `vvp_darray_object` level per declared
// dimension, each recording its own bounds -- by walking the property's
// declared dimensions, and `%store/prop/arr/dar` walks it back.
//
// A plain 2-D VARIABLE did not. It was rejected at elaboration with
// "the type of the variable 'm' doesn't match the context type", and
// both gates that rejected it failed for the same reason: a signal
// expression's `net_type()` is its ELEMENT type, so neither the
// `elab_and_eval` cast check nor the `PEIdent` context check ever saw
// the `netuarray_t` at all.
//
// Opening those gates alone was not enough, and the way it failed is
// worth recording: a multi-dimensional signal is stored as ONE FLAT
// word array -- `int m[2][3]` emits `.array/2s "m", 5 0, 31 0`, six
// words -- so `%load/arr/dar` handed the callee a FLAT container where
// it iterated a nested one, and every element read back
//
//     Warning: get_word(vvp_object_t) not implemented for
//              vvp_darray_atom<int>
//
// with the sum coming out 0. The declared shape is not recoverable from
// the flat storage, so it is now handed over explicitly: `%dim/push`
// per dimension, then `%load/arr/dar/md` (or `%store/arr/dar/md` coming
// back) to build or walk the nesting. The bounds cannot ride in an
// operand of those instructions, because `vvp_code_s` keeps `array` and
// `text` in one union and the array pointer already occupies it.
//
// Any legal dimensionality is supported, not just two. Getting past two
// took three more fixes, each of which had been silently capped at two:
//
//   * the signal-side select chain took index.front() and index.back()
//     and dropped everything between, so `q[i][j][k]` READ `q[i][j]`;
//   * NetESelect::dup_expr() rebuilt a select through the sel_type_
//     constructor, dropping the net_type -- so a DUPLICATED container
//     select reported no type, and `foreach` over a three-deep container
//     elaborated two levels and then produced no loop at all for the
//     third. Zero iterations, no diagnostic;
//   * the nested STORE lowering passed exactly two keys, so a write at
//     depth three was refused outright, and once it wasn't, the value
//     kind was still read from an intermediate container level and the
//     store wrote a null.

module main;

  typedef struct { int md[1:2][7:5]; } P;

  int   m[2][3];
  int   desc[2:1][5:7];
  real  rm[2][2];
  P     p;
  int   flat[3];
  int   a3[2][2][2];
  int   a4[2][2][2][2];
  int   a5[2][2][2][2][2];
  int   nd[][];                 // a nested DYNAMIC array
  int   qq[$][$];               // a queue of queues
  int   am[string][];           // an associative array of dynamic arrays

  int fails = 0;

  task chk(string what, int got, int want);
    if (got !== want) begin
      fails++;
      $display("FAILED -- %s: got %0d want %0d", what, got, want);
    end
  endtask

  // ---- read side ----
  function automatic int sum2(input int q[][]);
    int t = 0;
    foreach (q[i,j]) t += q[i][j];
    return t;
  endfunction

  function automatic int outer_size(input int q[][]);
    return $size(q);
  endfunction

  function automatic int inner_size(input int q[][]);
    return $size(q[$left(q)]);
  endfunction

  function automatic int outer_left(input int q[][]);
    return $left(q);
  endfunction

  function automatic int outer_right(input int q[][]);
    return $right(q);
  endfunction

  function automatic real sumr2(input real q[][]);
    real t = 0.0;
    foreach (q[i,j]) t += q[i][j];
    return t;
  endfunction

  // ---- write side ----
  task automatic bump2(inout int q[][]);
    foreach (q[i,j]) q[i][j] = q[i][j] + 100;
  endtask

  task automatic bumpr2(inout real q[][]);
    foreach (q[i,j]) q[i][j] = q[i][j] + 1.5;
  endtask

  task automatic bump1(inout int q[]);
    foreach (q[i]) q[i] = q[i] + 100;
  endtask

  function automatic int sum3(input int q[][][]);
    int t = 0;
    foreach (q[i,j,k]) t += q[i][j][k];
    return t;
  endfunction

  function automatic int sum4(input int q[][][][]);
    int t = 0;
    foreach (q[i,j,k,l]) t += q[i][j][k][l];
    return t;
  endfunction

  function automatic int sum5(input int q[][][][][]);
    int t = 0;
    foreach (q[i,j,k,l,m]) t += q[i][j][k][l][m];
    return t;
  endfunction

  task automatic bump3(inout int q[][][]);
    foreach (q[i,j,k]) q[i][j][k] = q[i][j][k] + 100;
  endtask

  task automatic bump4(inout int q[][][][]);
    foreach (q[i,j,k,l]) q[i][j][k][l] = q[i][j][k][l] + 100;
  endtask

  initial begin
    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        m[i][j] = i*3 + j;                  // 0 1 2 / 3 4 5

    // ---- the shape that was rejected: a plain 2-D variable ----
    chk("read a plain 2-D actual", sum2(m), 15);

    // ---- declared bounds survive, per dimension (H.10.2) ----
    chk("outer size",  outer_size(p.md),  2);
    chk("inner size",  inner_size(p.md),  3);
    chk("outer left",  outer_left(p.md),  1);
    chk("outer right", outer_right(p.md), 2);

    // ---- copy-back into a plain 2-D variable ----
    bump2(m);
    chk("copy-back [0][0]", m[0][0], 100);
    chk("copy-back [0][2]", m[0][2], 102);
    chk("copy-back [1][0]", m[1][0], 103);
    chk("copy-back [1][2]", m[1][2], 105);

    // ---- a descending declared range, both dimensions ----
    desc[2][5] = 1; desc[2][6] = 2; desc[2][7] = 3;
    desc[1][5] = 4; desc[1][6] = 5; desc[1][7] = 6;
    bump2(desc);
    chk("descending 2-D [2][5]", desc[2][5], 101);
    chk("descending 2-D [1][7]", desc[1][7], 106);

    // ---- real elements: the read path had to learn nested
    //      containers too, or it aborted ivl outright ----
    rm[0][0] = 1.0; rm[0][1] = 2.0; rm[1][0] = 3.0; rm[1][1] = 4.0;
    if (sumr2(rm) != 10.0) begin
      fails++;
      $display("FAILED -- read a real 2-D actual: got %f want 10.0", sumr2(rm));
    end
    bumpr2(rm);
    if (rm[0][0] != 2.5 || rm[1][1] != 5.5) begin
      fails++;
      $display("FAILED -- real 2-D copy-back: got %f %f want 2.5 5.5",
               rm[0][0], rm[1][1]);
    end

    // ---- control: the struct member form, which already worked ----
    p.md[1][7] = 1; p.md[1][6] = 2; p.md[1][5] = 3;
    p.md[2][7] = 4; p.md[2][6] = 5; p.md[2][5] = 6;
    chk("control: read a 2-D member", sum2(p.md), 21);
    bump2(p.md);
    chk("control: member copy-back [1][7]", p.md[1][7], 101);
    chk("control: member copy-back [2][5]", p.md[2][5], 106);

    // ---- control: one dimension still takes the flat path ----
    flat = '{1, 2, 3};
    bump1(flat);
    chk("control: a 1-D actual", flat[2], 103);

    // ---- three, four and five dimensions ----
    begin
      automatic int n;
      n = 0;
      for (int i=0;i<2;i++) for (int j=0;j<2;j++) for (int k=0;k<2;k++)
        begin a3[i][j][k] = n; n++; end
      n = 0;
      for (int i=0;i<2;i++) for (int j=0;j<2;j++) for (int k=0;k<2;k++)
        for (int l=0;l<2;l++) begin a4[i][j][k][l] = n; n++; end
      n = 0;
      for (int i=0;i<2;i++) for (int j=0;j<2;j++) for (int k=0;k<2;k++)
        for (int l=0;l<2;l++) for (int m=0;m<2;m++)
          begin a5[i][j][k][l][m] = n; n++; end
    end

    chk("3-D read", sum3(a3),  28);      // 0..7
    chk("4-D read", sum4(a4), 120);      // 0..15
    chk("5-D read", sum5(a5), 496);      // 0..31

    bump3(a3);
    chk("3-D copy-back first", a3[0][0][0], 100);
    chk("3-D copy-back last",  a3[1][1][1], 107);

    bump4(a4);
    chk("4-D copy-back first", a4[0][0][0][0], 100);
    chk("4-D copy-back last",  a4[1][1][1][1], 115);

    // ---- sibling CONTAINER spellings of the same nested shape ----
    //
    // An open-array formal does not care which spelling it was given:
    // a queue and a dynamic array share vvp_darray at run time. The
    // outer level already had a queue/darray passthrough, but the
    // check compared INNER levels strictly, so a queue of queues was
    // refused with "the type of the variable 'qq' doesn't match the
    // context type" while the identical nested dynamic array was
    // accepted.
    nd = new[2];
    foreach (nd[i]) nd[i] = new[3];
    foreach (nd[i,j]) nd[i][j] = i*3 + j;
    qq = '{'{0,1,2}, '{3,4,5}};
    am["x"] = new[3];
    for (int i = 0; i < 3; i++) am["x"][i] = i;

    chk("nested dynamic array -> open", sum2(nd), 15);
    chk("queue of queues      -> open", sum2(qq), 15);

    bump2(nd);
    chk("nested dynamic array copy-back", nd[1][2], 105);
    bump2(qq);
    chk("queue of queues copy-back",      qq[1][2], 105);

    chk("assoc of dynamic arrays, element", am["x"][2], 2);

    if (fails == 0) $display("PASSED");
    else            $display("FAILED (%0d)", fails);
    $finish(0);
  end

endmodule
