// An assertion that references an UNDEFINED sequence compiles and then
// never evaluates. The property is silently inert.
//
//   $ iverilog -g2012 -o z.vvp this_file.sv
//   warning: Unable to bind wire/reg/memory `NoSuchSeq_S' in `top'
//            (compile-progress: unresolved reference).
//   $ vvp z.vvp
//   DONE                     <- the assertion never fired, not once
//
// `NoSuchSeq_S |=> 1'b0' cannot hold under any trace, so a live
// assertion would report on every clock. It reports nothing.
//
// This is the dangerous shape for a verification flow: the testbench
// compiles, the run is green, and a check the engineer believes is
// present does not exist. The unresolved name degrades to a
// compile-progress warning that is easily lost among thousands of
// lines of build output -- and unlike a typo'd signal, there is no
// later symptom.
//
// Related and probably the same root: named sequence declarations do
// not appear to register at all in simple cases. Two identically named
// sequences at module level --
//
//     sequence S1; p ##1 n; endsequence
//     sequence S1; n ##1 p; endsequence
//
// -- are accepted, even though pform_sva_declare_sequence (pform.cc)
// rejects a repeat in `sva_module_sequences' and that map is only
// cleared at endmodule (pform_sva_module_done). So the declarations are
// being parsed by some path that never reaches the registration, while
// OpenTitan's prim_alert_sender DOES reach it and collides. Whatever
// distinguishes the two is the thing to find; the silent-inert
// assertion above is the consequence worth fixing first.
//
// Found while reducing the OpenTitan duplicate-sequence root; see
// ot_sva_assertion_roots.md.
module top;
  logic clk = 0, p = 0;
  always #5 clk = ~clk;

  A: assert property (@(posedge clk) NoSuchSeq_S |=> 1'b0)
     else $display("ASSERTION FIRED at %0t", $time);

  initial begin
    repeat (4) @(posedge clk);
    $display("DONE");
    $finish;
  end
endmodule
