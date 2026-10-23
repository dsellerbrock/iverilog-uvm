module sv_instantiated_generate_hier_read;
  if (1) begin : g
    int v;
  end
  initial begin
    sv_instantiated_generate_hier_read.g.v = 7;
    if (sv_instantiated_generate_hier_read.g.v !== 7)
      $fatal(1, "hierarchical read of instantiated generate variable failed");
    $display("PASSED");
  end
endmodule
