// Companion to ivltests/sv_uwire_promote_generate: a procedural driver
// whose index is a RUN-TIME expression could land on any element, so the
// disjointness test must answer conservatively and keep rejecting the
// mixed drive. A bit-accurate test that only handled constant indices
// would accept this and let a real conflict compile.
module sv_uwire_generate_runtime_index;
  logic [3:0][7:0] st;
  logic [7:0] d = 8'hA5;
  logic [1:0] i;
  assign st[0] = d;
  for (genvar r = 0; r < 1; r++) begin : g
    always_comb st[i] = d + 1;   // may or may not be st[0]
  end
endmodule
