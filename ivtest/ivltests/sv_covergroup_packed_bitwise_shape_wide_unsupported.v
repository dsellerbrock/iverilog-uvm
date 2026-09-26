// Current coverage range IR is limited to 64 bits; keep wider packed
// bitwise coverpoints loudly unsupported until exact semantics exist.
module test;
  typedef struct packed { bit [64:0] bits; } wide_t;
  class cfg_t;
    wide_t err;
    wide_t mask;
  endclass
  class cov_t;
    cfg_t cfg;
    covergroup wide_cg;
      cp: coverpoint (cfg.err & ~cfg.mask) {
        bins zero = {0};
        bins nonzero = {[1:$]};
      }
    endgroup
    function new(cfg_t c);
      cfg = c;
      wide_cg = new;
    endfunction
  endclass
  cfg_t cfg;
  cov_t cov;
  initial begin
    cfg = new;
    cov = new(cfg);
    $display("UNSUPPORTED_WIDTH_DIAGNOSTIC");
  end
endmodule
