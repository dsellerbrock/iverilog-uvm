// Companion to ivltests/sv_uwire_promote_generate: making the var->uwire
// promotion bit-accurate must NOT let a genuine conflict through.
//
// Here BOTH drivers target st[0] -- a continuous assign and an
// always_comb inside a generate. IEEE 1800-2017 6.5 forbids exactly
// this. Before the change the promotion was refused for any generate
// process at all, so this was rejected by accident; it must still be
// rejected on purpose.
module sv_uwire_generate_same_element;
  logic [3:0][7:0] st;
  logic [7:0] d = 8'hA5;
  assign st[0] = d;
  for (genvar r = 0; r < 1; r++) begin : g
    always_comb st[0] = d + 1;
  end
endmodule
