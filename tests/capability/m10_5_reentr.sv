// M10-5: C -> SV -> C -> SV reentrancy across the DPI boundary
module top;
  import "DPI-C" context function int c_outer(input int v);
  import "DPI-C" context function int c_inner(input int v);
  export "DPI-C" function sv_mid;
  export "DPI-C" function sv_leaf;
  int mid_hits = 0, leaf_hits = 0;
  function int sv_mid(int x);  mid_hits++;  return c_inner(x) + 1; endfunction
  function int sv_leaf(int x); leaf_hits++; return x * 2;          endfunction
  initial begin
    int r, ok = 1;
    r = c_outer(3);           // c_outer -> sv_mid -> c_inner -> sv_leaf
    if (r != 3*2+1+100) begin $display("FAIL reentrancy r=%0d (expect %0d)", r, 3*2+1+100); ok = 0; end
    if (mid_hits != 1 || leaf_hits != 1)
      begin $display("FAIL hits mid=%0d leaf=%0d", mid_hits, leaf_hits); ok = 0; end
    if (ok) $display("PASS m10_5");
    $finish(0);
  end
endmodule
