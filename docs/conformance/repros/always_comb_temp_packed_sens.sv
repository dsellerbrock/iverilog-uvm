// Reproducer (WRONG SIMULATION, pre-existing): an always_comb can end up
// with an EMPTY sensitivity set, so it runs once at time 0 and never
// again, simulating a stale value for the rest of the run.
//
// The compiler is not silent about it -- it prints
//
//     warning: always_comb process has no sensitivities.
//
// preceded by
//
//     sorry: constant selects in always_* processes are not fully
//     supported (the process will be sensitive to all bits in 'st...').
//
// so this is a loud wrong result, not a silent one. (An earlier note in
// the OpenTitan document called it silent; that was wrong -- the
// warning was there and an error-only filter had hidden it.)
//
// Three ingredients are needed together. Removing any one is correct:
//
//   this file  : reads st[0], writes tmp, writes st[1]   -> STALE
//   drop tmp   : reads st[0], writes st[1]               -> correct
//   output out : reads st[0], writes tmp, writes `out'   -> correct
//                (out is not part of st)
//   scalar read: reads seed, writes tmp, writes out      -> correct
//
// So it takes a constant select whose sensitivity is widened to the
// WHOLE packed variable, plus a write to another element of that SAME
// variable, plus an intermediate written and read inside the block.
// nex_input(rem_out=true, always_sens=true) then yields nothing, and
// PEventStatement::elaborate_st keeps only the implicit T0 trigger.
//
// The widening is the root: net_nex_input.cc's NetESelect::nex_input
// cannot express "sensitive to st[0] only" (the bit/part-select
// sensitivity path is present but disabled), so it falls back to the
// whole variable -- which this process also writes.
//
// Found while building the var->uwire generate regression; independent
// of that fix, and reproduces with no continuous assign anywhere.
module top;
  logic [3:0][7:0] st;
  logic [7:0] seed, tmp;

  always_comb st[0] = seed;

  always_comb begin : p
    tmp   = st[0] ^ 8'h0F;
    st[1] = tmp + 8'd1;
  end

  initial begin
    seed = 8'hA5; #1;
    $display("seed=A5 st1=%h  (expect ab)", st[1]);
    seed = 8'h3C; #1;
    $display("seed=3C st1=%h  (expect 34)", st[1]);   // prints ab
  end
endmodule
