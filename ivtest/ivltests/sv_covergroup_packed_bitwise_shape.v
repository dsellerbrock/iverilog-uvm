// IEEE 1800-2017/2023: a packed-struct bitwise expression is an
// integral coverpoint; both its zero and open-ended nonzero bins count.
module test;
  typedef struct packed {
    bit high_err;
    bit post_trans_err;
    bit low_err;
  } err_inj_t;

  class cfg_t;
    err_inj_t err_inj;
  endclass

  class cov_t;
    cfg_t cfg;
    const err_inj_t ErrInjMask = '{post_trans_err: 1, default: 0};

    covergroup err_inj_cg;
      option.per_instance = 1;
      err_inj_cp: coverpoint (cfg.err_inj & ~ErrInjMask) {
        bins no_err_inj = {0};
        bins err_inj = {[1:$]};
      }
    endgroup

    function new(cfg_t c);
      cfg = c;
      err_inj_cg = new;
    endfunction

    function void sample_cov();
      err_inj_cg.sample();
    endfunction
  endclass

  cfg_t cfg;
  cov_t cov;
  initial begin
    cfg = new;
    cov = new(cfg);
    if (cov.err_inj_cg.get_inst_coverage() != 0.0)
      $fatal(1, "empty denominator: %f", cov.err_inj_cg.get_inst_coverage());

    cfg.err_inj = '0;
    cov.sample_cov();
    if (cov.err_inj_cg.get_inst_coverage() != 50.0)
      $fatal(1, "zero bin or two-bin denominator: %f",
             cov.err_inj_cg.get_inst_coverage());

    cfg.err_inj = '{post_trans_err: 1, default: 0};
    cov.sample_cov();
    if (cov.err_inj_cg.get_inst_coverage() != 50.0)
      $fatal(1, "masked-only sample hit nonzero bin: %f",
             cov.err_inj_cg.get_inst_coverage());

    cfg.err_inj = '{high_err: 1, default: 0};
    cov.sample_cov();
    if (cov.err_inj_cg.get_inst_coverage() != 100.0)
      $fatal(1, "high-bit nonzero bin or packed width: %f",
             cov.err_inj_cg.get_inst_coverage());
    $display("PASSED");
  end
endmodule
