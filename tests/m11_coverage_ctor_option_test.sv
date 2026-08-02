// IEEE 1800-2017 19.3/19.7: covergroup constructor arguments are
// per-instance constants and may control coverage options.
module m11_coverage_ctor_option_test;
  class wrapper;
    covergroup cg(bit enable_aux)
        with function sample(bit primary, bit auxiliary);
      cp_primary: coverpoint primary {
        bins zero = {0};
        bins one  = {1};
      }
      cp_auxiliary: coverpoint auxiliary {
        option.weight = enable_aux;
        bins zero = {0};
        bins one  = {1};
      }
    endgroup

    function new(bit enable_aux);
      cg = new(enable_aux);
    endfunction

    function void take(bit primary, bit auxiliary);
      cg.sample(primary, auxiliary);
    endfunction
  endclass

  wrapper enabled, disabled;
  real enabled_cov, disabled_cov;

  initial begin
    enabled = new(1);
    disabled = new(0);

    // Primary reaches 100%; auxiliary reaches 50%.
    enabled.take(0, 0);
    enabled.take(1, 0);
    disabled.take(0, 0);
    disabled.take(1, 0);

    enabled_cov = enabled.cg.get_inst_coverage();
    disabled_cov = disabled.cg.get_inst_coverage();
    if (enabled_cov != 75.0 || disabled_cov != 100.0) begin
      $display("M11 COVERGROUP CTOR OPTION TEST: FAIL enabled=%0.1f disabled=%0.1f",
               enabled_cov, disabled_cov);
      $finish(1);
    end
    $display("M11 COVERGROUP CTOR OPTION TEST: PASS");
    $finish(0);
  end
endmodule
