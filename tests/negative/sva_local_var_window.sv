// M9-NFA LV-1: a local variable across a VARIABLE-length delay needs
// per-slot storage (LV-2), which is not yet implemented -- must be a
// loud sorry, never a silent miscompile.
module sva_local_var_window;
  logic clk=0, a=0, b=0;
  logic [7:0] d=0, c=0;
  always #5 clk=~clk;
  w: assert property (@(posedge clk) (a, v = d) ##[1:3] (b && (c == v)));
  initial begin repeat(3) @(negedge clk); $finish(0); end
endmodule

// NEG-LEGACY-ONLY: the automaton engine (now default) lowers this
// construct; this file verifies the legacy engine still rejects it loudly.
