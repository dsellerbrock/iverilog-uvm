// Companion to ivltests/sv_uwire_promote_generate: a procedural driver
// with no part select covers the WHOLE variable, so it conflicts with a
// continuous assign to any element of it.
module sv_uwire_generate_whole_signal;
  logic [3:0][7:0] st;
  logic [7:0] d = 8'hA5;
  assign st[0] = d;
  for (genvar r = 0; r < 1; r++) begin : g
    always_comb st = 32'h0;
  end
endmodule
