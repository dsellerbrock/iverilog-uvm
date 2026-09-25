// A bitwise packed-struct coverpoint does not make [$:$] a legal range.
module test;
  typedef struct packed { bit high_err; bit post_trans_err; } err_inj_t;
  class cfg_t;
    err_inj_t err_inj;
  endclass
  class cov_t;
    cfg_t cfg;
    const err_inj_t ErrInjMask = '{post_trans_err: 1, default: 0};
    covergroup err_inj_cg;
      cp: coverpoint (cfg.err_inj & ~ErrInjMask) {
        bins invalid = {[$:$]};
      }
    endgroup
  endclass
endmodule
