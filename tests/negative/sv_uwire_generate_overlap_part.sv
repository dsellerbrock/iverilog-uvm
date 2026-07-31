// Companion to ivltests/sv_uwire_promote_generate: overlapping PART
// selects are a conflict even though neither driver covers the whole
// variable. v[15:8] continuously and v[11:4] procedurally share bits
// 11:8 (IEEE 1800-2017 6.5).
module sv_uwire_generate_overlap_part;
  logic [31:0] v;
  logic [7:0] d = 8'hA5;
  assign v[15:8] = d;
  for (genvar r = 0; r < 1; r++) begin : g
    always_comb v[11:4] = d;
  end
endmodule
