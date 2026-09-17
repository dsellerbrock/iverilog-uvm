// The undotted counterpart of `foreach (obj.key[0].member[i])'-style
// selected-prefix targets: `foreach (arr[id][j])' where `arr' is a
// nested array and the FIRST bracket's identifier is meant as a fixed
// selector (IEEE 1800-2017/2023 12.7.3), not a second loop variable.
// A bare identifier in that position is syntactically ambiguous with a
// length-1 `loop_variables' list; the grammar resolves it as a
// selector, which is only meaningful when the identifier already
// names a variable declared in an enclosing scope. When it does not
// (a plain typo, or a genuinely-intended-but-unsupported second loop
// variable across two bracket groups instead of the standard
// comma-separated form), this must be a real, focused elaboration
// error -- not a silent pass with undefined behavior. Confirmed
// independently: slang (--std 1800-2017) rejects this exact
// construct too, as "use of undeclared identifier 'k1'".
module main;
  int m[int][int];
  initial foreach (m[k1][k2]) $display(k1, k2);
endmodule
