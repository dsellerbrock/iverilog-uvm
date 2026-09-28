// IEEE 1800-2017/2023 7.6, 7.8: OpenTitan flash_ctrl fixed-value maps
// must diagnose variable-size whole-map pattern items until transactional
// run-time size checking is supported.
module top;
  typedef bit [7:0] pair_t[3:2];
  pair_t m[int];
  bit [7:0] d[];
  bit [7:0] q[$];
  initial begin
    m = '{default: d};
    m = '{7: q};
  end
endmodule
