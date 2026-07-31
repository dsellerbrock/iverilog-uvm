// An assertion that references an UNDEFINED name must be an ERROR, not
// a compile-progress warning.
//
// `NoSuchSeq_S |=> 1'b0' cannot hold under any trace, so a live
// assertion would report on every clock. It reported nothing: the
// unresolved name degraded to
//
//   warning: Unable to bind wire/reg/memory `NoSuchSeq_S' ...
//            (compile-progress: unresolved reference).
//
// and the property became permanently inert. For a verification flow
// that is the worst shape available -- the testbench builds, the run is
// green, and a check the engineer believes exists does not, with no
// later symptom, unlike a mistyped signal in ordinary RTL.
//
// The compile-progress fallback still applies everywhere else: it
// exists so UVM-heavy code keeps building through parameterized
// container typing losses, and uvm-core/src contains no concurrent
// assertions at all, so an SVA-scoped strictness cannot reach it.
module sva_undefined_name_inert;
  logic clk = 0, p = 0;
  A: assert property (@(posedge clk) NoSuchSeq_S |=> p);
endmodule
