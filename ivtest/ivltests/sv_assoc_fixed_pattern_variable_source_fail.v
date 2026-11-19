// A selected nested map has no checked whole-map store yet.
module top;
  typedef bit [7:0] pair_t[3:2];
  typedef pair_t map_t[int];
  map_t maps[int];
  bit [7:0] d[];
  initial maps[1] = '{default: d};
endmodule
