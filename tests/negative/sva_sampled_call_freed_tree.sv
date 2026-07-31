// A sampled-value function inside an assertion that is DROPPED on a
// `sorry' path must not crash the compiler.
//
// pform_note_sampled_call parks a raw PECallFunction* in a module-level
// vector so an unclocked $rose/$fell/$past can be diagnosed at
// endmodule. When the assertion is dropped, its expression tree is
// freed -- but the parked entry survived, and the endmodule flush then
// called p.call->get_fileline() on the freed node:
//
//   sorry: a sequence `or'/`and'/`throughout' combinator as the
//          consequent of an implication is not supported yet ...
//   Segmentation fault            <- exit 139
//
// Four lines of input, and the compiler dies. The flush now uses the
// location it captured by value, and the destroy paths forget any
// parked entry before freeing the tree.
//
// This test only discriminates because run_negative.sh treats exit
// status >= 128 as a FAILURE rather than a rejection -- the `sorry' is
// printed before the crash, so a signal death otherwise looked exactly
// like a clean reject.
module sva_sampled_call_freed_tree;
  logic clk = 0, a = 0, b = 0, c = 0;
  A: assert property (@(posedge clk) $rose(a) |-> b and c);
endmodule
