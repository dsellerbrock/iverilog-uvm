// IEEE 1800-2017 12.7.1: for_initialization may hold SEVERAL
// comma-separated variable declarations, each with its own data type:
//
//   for (int i = 0, state_e t = t.first(); i < t.num(); i += 1, t = t.next())
//
// Only one declaration was accepted; a second was "Incomprehensible for
// loop" / "Syntax error defining function". A comma-separated STEP list
// already worked -- it was only the initialization list that was limited.
//
// This is the shape OpenTitan's prim_sparse_fsm_flop uses to walk an
// enumeration, so it gated every assertion-enabled build of any IP with a
// sparse FSM.
//
// The test checks the loop actually COMPUTES correctly -- declaration
// order, per-clause types, and multiple step assignments -- not just that
// it parses.

module sv_for_multi_var_decl;

  typedef enum logic [2:0] { S0 = 3'b001, S1 = 3'b010, S2 = 3'b100 } state_e;

  int errors = 0;

  // Two declarations, two step assignments. Both variables must advance.
  function automatic int two_decls();
    int s = 0;
    for (int i = 0, int j = 3; i < 4; i += 1, j -= 1) s += i * 10 + j;
    return s;
  endfunction

  // Two declarations, ONE step assignment: j must keep its initial value.
  function automatic int one_step();
    int s = 0;
    for (int i = 0, int j = 3; i < 4; i += 1) s += i + j;
    return s;
  endfunction

  // Three declarations with different types.
  function automatic int three_decls();
    int s = 0;
    for (int i = 0, byte b = 2, int k = 5; i < 2; i += 1) s += b + k;
    return s;
  endfunction

  // A later clause reading a variable an earlier clause just set: the
  // initializers must run in SOURCE ORDER.
  function automatic int ordered_init();
    int s = 0;
    for (int i = 2, int j = i * 10; i < 3; i += 1) s += j;
    return s;
  endfunction

  // The prim_sparse_fsm_flop shape: a typed enum declaration whose
  // initializer is a method on the variable being declared.
  function automatic logic is_undefined_state(state_e sig);
    logic is_defined = 1'b0;
    for (int i = 0, state_e t = t.first(); i < t.num(); i += 1, t = t.next()) begin
      is_defined |= (sig === t);
    end
    return ~is_defined;
  endfunction

  initial begin
    // i*10+j over (0,3)(1,2)(2,1)(3,0) = 3+12+21+30
    if (two_decls() !== 66) begin
      $display("FAILED -- two_decls() = %0d, want 66", two_decls());
      errors++;
    end
    // (0+3)+(1+3)+(2+3)+(3+3)
    if (one_step() !== 18) begin
      $display("FAILED -- one_step() = %0d, want 18", one_step());
      errors++;
    end
    // (2+5) twice
    if (three_decls() !== 14) begin
      $display("FAILED -- three_decls() = %0d, want 14", three_decls());
      errors++;
    end
    // j = i*10 = 20, one iteration
    if (ordered_init() !== 20) begin
      $display("FAILED -- ordered_init() = %0d, want 20 (initializers ran out of order)",
               ordered_init());
      errors++;
    end
    if (is_undefined_state(S1) !== 1'b0) begin
      $display("FAILED -- is_undefined_state(S1) = %b, want 0", is_undefined_state(S1));
      errors++;
    end
    if (is_undefined_state(state_e'(3'b111)) !== 1'b1) begin
      $display("FAILED -- is_undefined_state(3'b111) = %b, want 1",
               is_undefined_state(state_e'(3'b111)));
      errors++;
    end

    if (errors == 0) $display("PASSED");
    $finish(0);
  end

endmodule
