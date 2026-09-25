// IEEE 1800-2017/2023: bitwise operands use the result width and a
// result is signed only when both operands are signed.
module test;
  typedef struct packed { bit high; bit [3:0] low; } err5_t;
  typedef struct packed { bit [2:0] low; } mask3_t;

  class cfg_t;
    err5_t err;
    mask3_t mask;
    logic signed [4:0] signed_err;
    logic signed [2:0] signed_mask;
  endclass

  class cov_t;
    cfg_t cfg;
    covergroup mixed_cg;
      option.per_instance = 1;
      cp: coverpoint (cfg.err & ~cfg.mask) {
        bins zero = {0};
        bins low = {[1:15]};
        bins high = {[16:$]};
      }
    endgroup
    covergroup signed_cg;
      option.per_instance = 1;
      cp: coverpoint (cfg.signed_err & ~cfg.signed_mask) {
        bins zero = {0};
        bins negative = {[-16:-1]};
      }
    endgroup
    covergroup mixed_sign_cg;
      option.per_instance = 1;
      cp: coverpoint (cfg.signed_err & ~cfg.mask) {
        bins zero = {0};
        bins positive_16 = {16};
      }
    endgroup

    function new(cfg_t c);
      cfg = c;
      mixed_cg = new;
      signed_cg = new;
      mixed_sign_cg = new;
    endfunction
    function void sample_mixed();
      mixed_cg.sample();
    endfunction
    function void sample_signed();
      signed_cg.sample();
    endfunction
    function void sample_mixed_sign();
      mixed_sign_cg.sample();
    endfunction
  endclass

  function automatic bit near(real got, real want);
    return got > want - 0.01 && got < want + 0.01;
  endfunction

  cfg_t cfg;
  cov_t cov;
  initial begin
    cfg = new;
    cov = new(cfg);
    if (cov.mixed_cg.get_inst_coverage() != 0.0 ||
        cov.signed_cg.get_inst_coverage() != 0.0 ||
        cov.mixed_sign_cg.get_inst_coverage() != 0.0)
      $fatal(1, "unsampled bins were hit");

    cfg.err = 5'b00000;
    cfg.mask = 3'b000;
    cov.sample_mixed();
    if (!near(cov.mixed_cg.get_inst_coverage(), 100.0/3.0))
      $fatal(1, "mixed zero denominator: %f",
             cov.mixed_cg.get_inst_coverage());
    cfg.err = 5'b00001;
    cfg.mask = 3'b001;
    cov.sample_mixed();
    if (!near(cov.mixed_cg.get_inst_coverage(), 100.0/3.0))
      $fatal(1, "mixed masked zero: %f",
             cov.mixed_cg.get_inst_coverage());
    cfg.err = 5'b10000;
    cfg.mask = 3'b001;
    cov.sample_mixed();
    if (!near(cov.mixed_cg.get_inst_coverage(), 200.0/3.0))
      $fatal(1, "5-bit high bin or operand extension: %f",
             cov.mixed_cg.get_inst_coverage());
    cfg.err = 5'b00010;
    cfg.mask = 3'b000;
    cov.sample_mixed();
    if (cov.mixed_cg.get_inst_coverage() != 100.0)
      $fatal(1, "mixed low bin: %f", cov.mixed_cg.get_inst_coverage());

    cfg.signed_err = 0;
    cfg.signed_mask = 0;
    cfg.mask = 3'b000;
    cov.sample_signed();
    cov.sample_mixed_sign();
    if (cov.signed_cg.get_inst_coverage() != 50.0 ||
        cov.mixed_sign_cg.get_inst_coverage() != 50.0)
      $fatal(1, "signed/mixed zero denominators");
    cfg.signed_err = 15;
    cov.sample_signed();
    cov.sample_mixed_sign();
    if (cov.signed_cg.get_inst_coverage() != 50.0 ||
        cov.mixed_sign_cg.get_inst_coverage() != 50.0)
      $fatal(1, "positive gap hit an ordinary bin");
    cfg.signed_err = -16;
    cfg.signed_mask = 1;
    cov.sample_signed();
    cov.sample_mixed_sign();
    if (cov.signed_cg.get_inst_coverage() != 100.0)
      $fatal(1, "signed -16 endpoint or result type: %f",
             cov.signed_cg.get_inst_coverage());
    if (cov.mixed_sign_cg.get_inst_coverage() != 100.0)
      $fatal(1, "mixed signed/unsigned 16 bin: %f",
             cov.mixed_sign_cg.get_inst_coverage());
    $display("PASSED");
  end
endmodule
