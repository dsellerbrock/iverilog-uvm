// IEEE 1800-2017/2023 6.20.2 with 6.24.1 -- once an untyped parameter takes
// type `string' from its override (see sv_param_string_override_untyped), a
// size cast on it is illegal: 6.24.1 size casting applies to integral
// expressions, and a string is not integral.
//
// This is the residual, correctly-rejected half of the prim_lfsr_tb blocker.
// prim_lfsr.sv:283 writes `64'(LfsrType)' while prim_lfsr_tb.sv:23 overrides
// LfsrType from a `localparam string', so the two files together are invalid.
// slang 11.0.448 rejects the same combination: "cannot change width or
// signedness of non-integral expression (type is 'string')".
//
// Before the net_design.cc fix this file did not reach a diagnostic at all --
// the compiler segfaulted first. It must stay a LOUD rejection, never silent
// acceptance and never a crash.

module sub #(parameter LfsrType = "GAL_XOR") ();
  if (64'(LfsrType) == 64'("GAL_XOR")) begin : gen_gal
    initial $display("gal");
  end
endmodule

module main;
  localparam string TypedKind = "FIB_XNOR";
  sub #(.LfsrType(TypedKind)) u();
endmodule
