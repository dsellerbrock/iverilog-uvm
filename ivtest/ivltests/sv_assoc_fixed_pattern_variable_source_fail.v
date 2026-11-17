// IEEE 1800-2017/2023 7.6, 7.8: class-property patterns retain the
// unsupported diagnostic until transactional installation is supported.
class cfg;
  typedef bit [7:0] pair_t[3:2];
  pair_t m[int];
  bit [7:0] d[];
  bit [7:0] q[$];
  function void assign_patterns();
    m = '{default: d};
    m = '{7: q};
  endfunction
endclass
module top;
  typedef bit [7:0] pair_t[3:2];
  typedef pair_t map_t[int];
  map_t maps[int];
  bit [7:0] d[];
  cfg c;
  initial begin c = new; c.assign_patterns(); maps[1] = '{default:d}; end
endmodule
