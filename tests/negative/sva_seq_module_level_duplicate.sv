// Companion to ivltests/sva_seq_generate_scope: scoping named sequences
// to their generate block must NOT stop rejecting a genuine duplicate.
//
// These two declarations are in the SAME scope -- module level, no
// generate -- so this is a real redeclaration and must stay an error.
// A fix that merely relaxed the duplicate check, rather than adding a
// scope component to the key, would accept this.
module sva_seq_module_level_duplicate;
  logic clk = 0, p = 0, n = 0;
  sequence S1; p ##1 n; endsequence
  sequence S1; n ##1 p; endsequence
endmodule
