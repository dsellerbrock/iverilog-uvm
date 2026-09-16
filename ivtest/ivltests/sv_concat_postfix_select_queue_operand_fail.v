// A queue or dynamic-array operand is not a legal concatenation operand
// without an enclosing array-typed context (IEEE 1800-2017/2023 10.10);
// `{...}[...]' used as a bare sub-expression offers no such context, so
// this is always the packed bit-vector concatenation, and a queue/darray
// operand there is illegal (confirmed independently: slang rejects the
// identical construct with "invalid operand type ... in concatenation").
// Icarus used to silently treat the queue as if it were vector bits
// instead of rejecting it, producing a wrong (empty/zero) result with no
// diagnostic at all.
module main;
  string qa[$] = {"aa", "bb"};
  string qb[$] = {"cc", "dd"};
  string s;

  initial
    s = {qa, qb}[1];
endmodule
