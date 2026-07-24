// Recursive re-entry: C calls an automatic export, whose body calls back
// into C, which calls the SAME export again. Each level must hold its own
// frame -- the deepest returns first and the outer levels must be intact.
module top;
  import "DPI-C" context function int c_enter(input int n);
  export "DPI-C" function sv_rec;
  int trace[8]; int depth = 0;
  function automatic int sv_rec(int n);
    int mine = n;              // per-frame
    trace[depth] = n; depth++;
    if (n > 0) void'(c_enter(n - 1));
    if (mine != n) $display("FAIL frame clobbered at n=%0d saw %0d", n, mine);
    return mine;
  endfunction
  initial begin
    int ok = 1;
    void'(c_enter(3));
    if (depth != 4) begin $display("FAIL depth=%0d expect 4", depth); ok = 0; end
    if (trace[0]!=3||trace[1]!=2||trace[2]!=1||trace[3]!=0) begin
      $display("FAIL trace=%0d,%0d,%0d,%0d", trace[0],trace[1],trace[2],trace[3]); ok=0; end
    if (ok) $display("PASS m10_4h_recurse");
    $finish(0);
  end
endmodule
