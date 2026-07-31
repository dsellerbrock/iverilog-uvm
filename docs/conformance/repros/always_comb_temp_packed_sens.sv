// Reproducer (SILENT WRONG RESULT, pre-existing): an always_comb that
// BOTH reads a packed-array element AND writes an intermediate variable
// stops re-triggering. The stale value is simulated with no error and
// no warning.
//
// Three variants, all on the same compiler:
//
//   reads st[0], writes tmp, then st[1]   -> STALE   (this file)
//   reads seed (scalar), writes tmp       -> correct
//   reads st[0], no intermediate          -> correct
//
// So neither the element read nor the intermediate is enough on its
// own; the combination is. The "sorry: constant selects in always_*
// processes are not fully supported (the process will be sensitive to
// all bits in ...)" note points at the select handling: the fallback
// widens sensitivity to the whole packed variable, which this process
// also WRITES, and the self-write exclusion for always_comb
// (IEEE 1800-2017 9.2.2.4) then appears to remove it entirely.
//
// Found while building the var->uwire generate regression; unrelated to
// that fix -- it reproduces with no continuous assign anywhere.
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
