module test;
  class cfg_t;
    logic signed [4:0] signed_err;
    logic signed [2:0] signed_mask;
  endclass
  class cov_t;
    cfg_t cfg;
    covergroup expr_cg;
      option.per_instance = 1;
      cp: coverpoint (cfg.signed_err & ~cfg.signed_mask) {
        bins zero = {0};
        bins negative = {[-16:-1]};
      }
    endgroup
    covergroup direct_cg;
      option.per_instance = 1;
      cp: coverpoint cfg.signed_err {
        bins zero = {0};
        bins negative = {[-16:-1]};
      }
    endgroup
    function new(cfg_t c);
      cfg = c;
      expr_cg = new;
      direct_cg = new;
    endfunction
    function void sample_it();
      logic signed [4:0] evaluated;
      evaluated = cfg.signed_err & ~cfg.signed_mask;
      $display("source=%b expression=%b before=%f/%f",
               cfg.signed_err, evaluated,
               expr_cg.get_inst_coverage(), direct_cg.get_inst_coverage());
      expr_cg.sample();
      direct_cg.sample();
      $display("after=%f/%f",
               expr_cg.get_inst_coverage(), direct_cg.get_inst_coverage());
    endfunction
  endclass
  cfg_t cfg;
  cov_t cov;
  initial begin
    cfg = new;
    cov = new(cfg);
    cfg.signed_err = 'x;
    cfg.signed_mask = 0;
    cov.sample_it();
    if (cov.expr_cg.get_inst_coverage() != 0.0 ||
        cov.direct_cg.get_inst_coverage() != 0.0)
      $fatal(1, "X sample incorrectly hit ordinary numeric bin");
    $display("PASSED");
  end
endmodule
