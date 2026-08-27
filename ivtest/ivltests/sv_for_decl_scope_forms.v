// IEEE 1800-2017/2023 12.7.1 and Syntax 12-5: the implicit block a declaring
// for-loop creates, and the parse-time scope effects that depend on it.
//
// The implicit scope must exist BEFORE the data_type is parsed, because an
// anonymous inline enum registers its literals at parse time (6.19). It must
// also hold the declared control variables BEFORE the condition and step are
// lexed: a declarator whose name shadows a visible typedef is otherwise
// returned as a type identifier by the lexer and silently binds the condition
// to the type instead of the loop variable.
//
// 12.7.1 also fixes the scope's identity: it is not user-addressable unless
// the source loop carries a statement label, in which case the label names it.

module sv_for_decl_scope_forms;

  typedef int shadow_t;
  // A variable name that is also a visible type name. The declarator below is
  // lexed as a type identifier, which is exactly the case that regressed.
  typedef int shadow;

  int errors = 0;

  // --- Anonymous inline enum identity and non-leakage --------------------
  // Two sibling loops each declare their own anonymous enum with the same
  // literal spellings. They must not collide with one another, and neither
  // set may leak into the enclosing block.
  function automatic int inline_enum_identity();
    int acc = 0;
    for (enum {A, B} e1 = e1.first(), int n = 0; n < 2; e1 = e1.next(), n++)
      acc = acc * 10 + int'(e1);
    for (enum {A, B} e2 = e2.first(), int n = 0; n < 2; e2 = e2.next(), n++)
      acc = acc * 10 + int'(e2) + 5;
    return acc;
  endfunction

  // --- Declarator name that shadows a visible type ----------------------
  // `shadow' is a typedef, so the declarator is lexed as a type identifier.
  // The condition and the step must still bind the declared loop variable.
  function automatic int shadowing_declarator();
    int iterations = 0;
    for (int shadow = 0; shadow < 3; shadow++)
      iterations++;
    return iterations;
  endfunction

  // The same name used as a same-type continuation, after a normal declarator.
  function automatic int shadowing_continuation();
    int acc = 0;
    for (int i = 0, shadow = i + 4; i < 3; i++, shadow++)
      acc = acc * 10 + shadow;
    return acc;
  endfunction

  // --- Ordered initialization and outer binding -------------------------
  // An earlier initializer may bind an OUTER name that a later loop-local
  // declarator subsequently shadows (12.7.1 with 6.21 scope rules).
  int outer_seed = 9;
  function automatic int outer_then_shadowed();
    int acc = 0;
    // `outer_seed' on the right of the first initializer is the module-level
    // variable; the second declarator then introduces a loop-local one.
    for (int first = outer_seed, int outer_seed = 1; first > 8; first--)
      acc = first * 10 + outer_seed;
    return acc;
  endfunction

  // --- Explicit whole-struct initialization suppresses member defaults ---
  typedef struct { int x; int y; } pair_t;
  function automatic int struct_defaults_suppressed();
    int acc = 0;
    for (pair_t p = '{x: 7, y: 9}, int once = 0; once < 1; once++)
      acc = p.x * 100 + p.y;
    return acc;
  endfunction

  // --- Lifetime: loop control automatic, body statics preserved ---------
  int auto_result[2];
  int body_static_seen[2];

  // Static task: 12.7.1 still requires the loop-control variable to be
  // automatic per activation, while an explicitly static body local keeps
  // its normal shared lifetime.
  task static lifetime_probe(input int id);
    automatic int captured = id;
    automatic int digits = 0;
    static   int shared_body = 0;
    for (int i = 0; i < 3; i++) begin
      digits = digits * 10 + i;
      shared_body++;
      #1;
    end
    auto_result[captured] = digits;
    body_static_seen[captured] = shared_body;
  endtask

  // --- Detached child retains the correct automatic loop frame ----------
  // 12.7.1 creates ONE automatic control variable when the loop statement is
  // entered, not one per iteration, so a child that outlives the loop reads
  // its final value (3). The per-iteration body-local `snapshot' is a
  // distinct automatic per activation, and each detached child must still
  // reach its own frame's copy after the loop has finished.
  int detached_seen[3];
  task automatic detached_frames();
    for (int i = 0; i < 3; i++) begin
      automatic int snapshot = i;
      fork
        begin
          #2;
          detached_seen[snapshot] = snapshot * 10 + i;
        end
      join_none
    end
    #10;
  endtask

  // --- Labeled implicit scope -------------------------------------------
  // A statement label names the implicit block, so %m resolves through it.
  // Kept at module level: this compiler does not report ANY named block
  // through %m from inside a subroutine (a plain `begin : name' behaves the
  // same way), so a task would test that unrelated limitation instead.
  string label_scope;
  int label_visits;

  initial begin
    if (inline_enum_identity() !== 32'd0156) begin
      $display("FAIL inline enum identity: %0d", inline_enum_identity());
      errors++;
    end

    if (shadowing_declarator() !== 3) begin
      $display("FAIL shadowing declarator iterations: %0d",
               shadowing_declarator());
      errors++;
    end

    if (shadowing_continuation() !== 456) begin
      $display("FAIL shadowing continuation: %0d", shadowing_continuation());
      errors++;
    end

    if (outer_then_shadowed() !== 91) begin
      $display("FAIL outer-then-shadowed initialization: %0d",
               outer_then_shadowed());
      errors++;
    end

    if (struct_defaults_suppressed() !== 709) begin
      $display("FAIL struct default suppression: %0d",
               struct_defaults_suppressed());
      errors++;
    end

    auto_result[0] = -1; auto_result[1] = -1;
    fork
      lifetime_probe(0);
      lifetime_probe(1);
    join
    if (auto_result[0] !== 12 || auto_result[1] !== 12) begin
      $display("FAIL automatic loop control: %0d %0d",
               auto_result[0], auto_result[1]);
      errors++;
    end
    // The static body local is shared by both activations, so the second
    // completing call must observe all six increments.
    if (body_static_seen[0] !== 6 || body_static_seen[1] !== 6) begin
      $display("FAIL static body local lifetime: %0d %0d",
               body_static_seen[0], body_static_seen[1]);
      errors++;
    end

    detached_seen[0] = -1; detached_seen[1] = -1; detached_seen[2] = -1;
    detached_frames();
    if (detached_seen[0] !== 3 || detached_seen[1] !== 13
        || detached_seen[2] !== 23) begin
      $display("FAIL detached child loop frame: %0d %0d %0d",
               detached_seen[0], detached_seen[1], detached_seen[2]);
      errors++;
    end

    // The label names the implicit block: %m resolves through it, and
    // `disable' targets it, leaving the loop after a single visit.
    loop2: for (int i = 0; i < 3; i++) begin
      label_visits++;
      label_scope = $sformatf("%m");
      disable loop2;
    end
    if (label_scope != "sv_for_decl_scope_forms.loop2" || label_visits != 1) begin
      $display("FAIL labeled implicit scope: %0s visits=%0d",
               label_scope, label_visits);
      errors++;
    end

    // The loop variable must not escape: `i' is not visible here. That is
    // pinned by the companion negative test sv_for_decl_scope_escape.

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
