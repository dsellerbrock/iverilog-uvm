// Regression: a default argument that is a method call must be evaluated in
// the CALLER's context (its `this`), not the callee's.
//
// This is OpenTitan issue #7 (cip_tl_seq_item):
//   virtual function tl_a_user_t compute_a_user(
//       mubi4_t instr_type = get_instr_type(), int racl_role = 0);
//   ... is_a_chan_intg_ok() calls compute_a_user();  // both args defaulted
// get_instr_type() reads `this.a_user` via a cast. The default get_instr_type()
// was elaborated in compute_a_user's scope, so its `this` referenced
// compute_a_user's port-0 net, which is unbound when the caller evaluates the
// default -> get_instr_type() ran on a null/unset `this` -> returned 0 ->
// wrong recomputed cmd integrity -> false d_error scoreboard mispredict.
//
// Fix: at the call site, rebind `this` references in the (callee-elaborated)
// default expression to the call's actual receiver.

typedef struct packed {
  bit [3:0] instr_type;
  bit [3:0] other;
} user_t;

class item;
  // packed struct: first field (instr_type) occupies the HIGH nibble.
  // a_user = 0x59 -> instr_type = 0x5, other = 0x9.
  bit [7:0] a_user = 8'h59;

  // virtual + reads a_user via a cast, like get_instr_type()
  virtual function bit [3:0] get_instr_type();
    user_t u = user_t'(a_user);
    return u.instr_type;
  endfunction

  // two defaulted args; first defaults to a method call on `this`
  virtual function bit [7:0] compute(bit [3:0] instr_type = get_instr_type(),
                                     int role = 0);
    return {instr_type, role[3:0]};
  endfunction

  // implicit-this call with NO args -> both defaults apply (the OT form)
  function bit [7:0] caller_implicit();
    return compute();
  endfunction
endclass

module top;
  initial begin
    item o = new();
    int errors = 0;
    bit [3:0] git        = o.get_instr_type();      // expect 0x5 (high nibble of a_user)
    bit [7:0] r_handle   = o.compute();             // default instr_type=get_instr_type()=5, role=0
    bit [7:0] r_implicit = o.caller_implicit();     // OT form
    bit [7:0] r_explicit = o.compute(4'ha, 2);      // control: explicit args

    $display("get_instr_type()        = 0x%0h (expect 0x5)", git);
    $display("compute() via handle    = 0x%02h (expect 0x50)", r_handle);
    $display("caller_implicit()       = 0x%02h (expect 0x50)", r_implicit);
    $display("compute(4'ha,2)         = 0x%02h (expect 0xa2)", r_explicit);

    if (git        !== 4'h5)  begin $display("FAIL: get_instr_type cast read"); errors++; end
    if (r_handle   !== 8'h50) begin $display("FAIL: default method-call arg (handle)"); errors++; end
    if (r_implicit !== 8'h50) begin $display("FAIL: default method-call arg (implicit this / OT form)"); errors++; end
    if (r_explicit !== 8'ha2) begin $display("FAIL: explicit args"); errors++; end

    if (errors == 0) $display("PASS");
    else $display("default_arg_method_call_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule
