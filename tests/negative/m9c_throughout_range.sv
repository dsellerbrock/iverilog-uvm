// M9C negative: `throughout` over a variable-length window (##[m:n]) is
// not supported and must be diagnosed (dropped), never silently
// approximated.
module top;
  logic clk=0, en, a, b;
  always #5 clk=~clk;
  ap: assert property (@(posedge clk) en throughout (a ##[1:3] b));
  initial begin #50 $finish(0); end
endmodule

// NEG-LEGACY-ONLY: the automaton engine (now default) lowers this
// construct; this file verifies the legacy engine still rejects it loudly.
