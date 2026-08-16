# Binary operand contextual sizing

## Scope

IEEE 1800-2017 11.8.1 determines the result size and signedness of a binary
expression before propagating that common type back to its context-determined
operands. A self-determined subexpression, such as an explicit `int'(...)`
cast, retains its 32-bit type internally but is subsequently converted when it
is used as an operand of a wider binary expression.

Icarus previously relied on the requested elaboration width to perform that
last conversion. A type-cast adapter could report the enclosing 33-bit width
while still exposing its self-determined 32-bit value during constant folding.
The enclosing binary node then asserted on the mismatch. The same missing
conversion could reach run-time arithmetic and bitwise lowering.

The elaborator now explicitly converts integral operands to the binary
expression's already-determined width and signedness before constructing the
netlist expression. The permanent regression covers:

- the untyped packed-struct parameter form used by Caliptra's VeeR core;
- explicit type, signing, and sizing casts in a wider binary expression;
- signed subtraction with a 32-bit self-determined operand in a 33-bit result;
- unsigned addition and bitwise conversion in the corresponding mixed-sign
  context.

The unmodified Caliptra `el2_veer_wrapper` manifest and the reduced source are
accepted after the fix; the reduced source is also accepted by Slang 11 in
IEEE 1800-2017 mode.
