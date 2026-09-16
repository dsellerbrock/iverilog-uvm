// A crash, not a coverage gap: an elaboration-time `$fatal()`/`$error()`/
// `$warning()`/`$info()` call whose argument fails to elaborate (e.g. an
// undefined identifier) must produce a clean diagnostic, never a
// segmentation fault. Confirmed independently: slang (--std 1800-2017)
// also rejects this construct (use of undeclared identifier), so the
// correct behavior here is a clear compile error, matching slang, not a
// crash.
//
// Real, unmodified OpenTitan RTL hits this directly: multiple
// `hw/*/ip_autogen/otp_ctrl/rtl/otp_ctrl.sv` files use the
// `ASSERT_INIT` macro (hw/ip/prim/rtl/prim_assert_standard_macros.svh)
// under `FPV_ON`, whose message-formatting arguments pass the
// assertion's own bare label token (e.g. `ScrmblKeyNotAllZero_A2`) as a
// plain expression rather than a string literal -- an undefined
// identifier in this compile context. Before this fix, Icarus segfaulted
// (SIGSEGV) partway through printing the "parameter [N] '...' is not
// constant" diagnostic: elab_sys_task_arg() returned a null NetExpr* for
// the unresolvable argument, and elaborate.cc's caller unconditionally
// dereferenced it (`*eparms[idx]`) to print its value, crashing on the
// null pointer instead of ever reaching that print. Reduced to this
// minimal case (a generate-if elaboration-time `$fatal` whose message
// argument is a bare undefined identifier).
module main;
  parameter logic [31:0] Key = 32'h0;
  if (!(Key != 0)) $fatal(2, "Fatal static assertion [%s]: (%s) is not true.",
                          (SomeAssertLabelNotAnIdentifier), (Key != 0));
endmodule
