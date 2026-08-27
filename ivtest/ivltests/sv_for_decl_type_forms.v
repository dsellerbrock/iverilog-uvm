// IEEE 1800-2017/2023 12.7 and 12.7.1 (Syntax 12-5): a
// for_initialization can contain one or more for_variable_declarations.
// Each declaration carries its own data_type and can itself contain several
// comma-separated variable initializers. The implicit loop scope gives every
// declared control variable automatic lifetime, even in a static subroutine.
//
// OpenTitan uses both forms that exposed the parser defect:
//   for (enum_t e = e.first(), int i = 0; ...)
//   for (pkg::enum_t e = pkg::First; ...)
// The first previously fell into the recovery rule when the typedef led the
// list; the second was consumed as a scoped assignment prefix. This test also
// covers the same-type continuation that Syntax 12-5 expressly requires.

package sv_for_decl_type_pkg;
  // Matches OpenTitan's package-qualified abstract_cmd_regno_t shape: the
  // named constants are enum literals, while the loop variable uses their
  // shared package typedef base so increment is ordinary integral increment.
  typedef logic [15:0] pkg_regno_t;
  typedef enum pkg_regno_t {
    PkgFirst = 0,
    PkgMiddle = 1,
    PkgLast = 2
  } pkg_regno_e;
endpackage

module sv_for_decl_type_forms;

  typedef enum int unsigned {
    LocalFirst = 0,
    LocalMiddle = 1,
    LocalLast = 2
  } local_state_e;

  int errors = 0;
  int lifetime_result[2];

  function automatic int same_type_continuations();
    int sum = 0;
    // j and k continue the first `int` for_variable_declaration. Their
    // initializers can see declarations to their left.
    for (int i = 0, j = i + 3, k = j + 2;
         i < 3;
         i++, j--, k += 2) begin
      sum += i * 100 + j * 10 + k;
    end
    return sum;
  endfunction

  function automatic int typedef_first_mixed();
    int sum = 0;
    // The typedef-led declaration is first; later declarations use distinct
    // integral types and retain source-order initialization.
    for (local_state_e state = state.first(),
         int i = 0,
         byte weight = i + 1;
         i < state.num();
         state = state.next(), i++, weight += 2) begin
      sum += (int'(state) + 1) * weight;
    end
    return sum;
  endfunction

  function automatic int package_qualified_single();
    int digits = 0;
    for (sv_for_decl_type_pkg::pkg_regno_t state =
             sv_for_decl_type_pkg::PkgFirst;
         state <= sv_for_decl_type_pkg::PkgLast;
         state++) begin
      digits = digits * 10 + int'(state) + 1;
    end
    return digits;
  endfunction

  function automatic int package_qualified_mixed();
    int sum = 0;
    for (sv_for_decl_type_pkg::pkg_regno_t state =
             sv_for_decl_type_pkg::PkgFirst,
         int i = 1;
         i <= 3;
         state++, i++) begin
      sum += (int'(state) + 1) * i;
    end
    return sum;
  endfunction

  // The task is intentionally static. Clause 12.7.1 still requires each
  // activation's loop-control variable to be automatic. Two overlapping
  // calls interleave at #1; shared/static i storage makes one call advance
  // the other's loop and neither call records the required 0,1,2 sequence.
  task static capture_automatic_loop(input int id);
    automatic int captured_id = id;
    automatic int sum = 0;
    for (int i = 0; i < 3; i++) begin
      sum = sum * 10 + i;
      #1;
    end
    lifetime_result[captured_id] = sum;
  endtask

  initial begin
    if (same_type_continuations() != 381) begin
      $display("FAIL same-type continuation: %0d", same_type_continuations());
      errors++;
    end

    if (typedef_first_mixed() != 22) begin
      $display("FAIL typedef-first mixed declarations: %0d",
               typedef_first_mixed());
      errors++;
    end

    if (package_qualified_single() != 123) begin
      $display("FAIL package-qualified single declaration: %0d",
               package_qualified_single());
      errors++;
    end

    if (package_qualified_mixed() != 14) begin
      $display("FAIL package-qualified mixed declarations: %0d",
               package_qualified_mixed());
      errors++;
    end

    lifetime_result[0] = -1;
    lifetime_result[1] = -1;
    fork
      capture_automatic_loop(0);
      capture_automatic_loop(1);
    join
    if (lifetime_result[0] != 12 || lifetime_result[1] != 12) begin
      $display("FAIL automatic loop-control lifetime: %0d %0d",
               lifetime_result[0], lifetime_result[1]);
      errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
