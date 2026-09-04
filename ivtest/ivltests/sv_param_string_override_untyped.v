// IEEE 1800-2017/2023 6.20.2 -- an UNTYPED parameter takes its type from the
// value it is finally assigned, and that value may be a string.
//
// Design::evaluate_parameter_logic_ (net_design.cc) switched on the value's
// expr_type() with no IVL_VT_STRING case, so a string-typed override fell to
// the `default' arm. That arm printed `param_type: ' << *param_type -- and
// param_type is NULL precisely when the parameter is untyped, which is the
// only way to reach this. The compiler therefore SEGFAULTED while printing
// its own "internal error: Unhandled expression type string?" message.
//
// A string LITERAL override arrives as a vector and lands in the IVL_VT_LOGIC
// arm, so only an override that keeps its string type reaches the bug -- which
// is why it survived until OpenTitan's prim_lfsr_tb hit it:
//
//   localparam string LfsrType = "GAL_XOR";        // prim_lfsr_tb.sv:23
//   prim_lfsr #(.LfsrType(LfsrType), ...) u (...); // prim_lfsr.sv:31 is untyped
//
// Pre-change this file does not compile at all: internal error + SIGSEGV.
//
// Note what this does NOT claim. Once the parameter correctly takes type
// `string', prim_lfsr's own `64'(LfsrType)' cast is illegal, and slang 11.0
// rejects that same combination -- "cannot change width or signedness of
// non-integral expression (type is 'string')". prim_lfsr_sim therefore stays
// blocked, on upstream source both tools reject, but it is no longer blocked
// by a compiler crash. The cast rejection is pinned separately by
// sv_param_string_cast_fail.

// No $display here: every instance is checked by hierarchical reference from
// main, so the only stdout this test produces is its verdict.
module sub #(parameter LfsrType = "GAL_XOR", parameter int W = 4) ();
endmodule

module main;

  int errors = 0;

  // A string-typed localparam overriding an untyped parameter: the crash.
  localparam string TypedKind = "FIB_XNOR";

  // Controls that already worked and must keep working.
  localparam        UntypedKind = "GAL_XOR";   // untyped, string value
  parameter  string TypedParam  = "GAL_XOR";

  sub #(.LfsrType(TypedKind),   .W(7)) u_typed   ();  // was: internal error + SIGSEGV
  sub #(.LfsrType("FIB_XNOR"),  .W(8)) u_literal ();  // literal override, control
  sub #(.LfsrType(UntypedKind), .W(9)) u_untyped ();  // untyped -> untyped, control
  sub #(.LfsrType(TypedParam), .W(10)) u_param   ();  // string parameter, control
  sub #(                        .W(11)) u_default (); // no override, control

  initial begin
    // The override must arrive with its value intact, not merely compile.
    if (u_typed.LfsrType    != "FIB_XNOR") begin $display("FAILED: typed override");    errors += 1; end
    if (u_literal.LfsrType  != "FIB_XNOR") begin $display("FAILED: literal override");  errors += 1; end
    if (u_untyped.LfsrType  != "GAL_XOR")  begin $display("FAILED: untyped override");  errors += 1; end
    if (u_param.LfsrType    != "GAL_XOR")  begin $display("FAILED: param override");    errors += 1; end
    if (u_default.LfsrType  != "GAL_XOR")  begin $display("FAILED: default value");     errors += 1; end

    // The string-typed localparam itself must survive unchanged.
    if (TypedKind != "FIB_XNOR") begin $display("FAILED: local string localparam"); errors += 1; end

    #1;
    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d error(s)", errors);
  end

endmodule
