// IEEE 1800-2017 19.6: a transition-bin coverpoint contributes the bin that
// completed on the current sample to a cross. Merely sampling the final value
// of a transition must not count a cross product.
module main;
  bit failed = 0;

  task check(string label, bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1;
    end
  endtask

  function automatic bit near(real got, real want);
    return got > want - 0.1 && got < want + 0.1;
  endfunction

  covergroup transition_cg with function sample(bit state, bit mode);
    state_cp: coverpoint state {
      bins rise = (0 => 1);
      bins fall = (1 => 0);
    }
    mode_cp: coverpoint mode {
      bins zero = {0};
      bins one = {1};
    }
    state_x_mode: cross state_cp, mode_cp;
  endgroup
  transition_cg cov = new;

  initial begin
    // This is the final value of `rise', but there was no preceding 0.
    // transition=0%, mode=50%, cross=0% => 16.666...%.
    cov.sample(1, 0);
    check("final value alone does not cross",
          near(cov.get_inst_coverage(), 16.6667));

    // Complete fall/mode0: transition=50%, mode=50%, cross=25%.
    cov.sample(0, 0);
    check("fall mode0 completion crosses",
          near(cov.get_inst_coverage(), 41.6667));

    // Complete rise/mode1, then fall/mode1, then rise/mode0.
    cov.sample(1, 1);
    check("rise mode1 completion crosses",
          near(cov.get_inst_coverage(), 83.3333));
    cov.sample(0, 1);
    check("fall mode1 completion crosses",
          near(cov.get_inst_coverage(), 91.6667));
    cov.sample(1, 0);
    check("all transition products complete",
          cov.get_inst_coverage() == 100.0);

    if (!failed) $display("PASSED");
    $finish(0);
  end
endmodule
