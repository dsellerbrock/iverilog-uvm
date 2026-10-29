module issue1429_illegal_transition_overlap;
  covergroup cg with function sample(input bit [1:0] value);
    cp: coverpoint value {
      bins path = (0 => 1 => 2 => 3);
      bins control = (3 => 0);
      illegal_bins bad = (2 => 3);
    }
  endgroup
  covergroup control_cg with function sample(input bit [1:0] value);
    cp: coverpoint value {
      bins path = (0 => 1 => 2 => 3);
      bins control = (3 => 0);
    }
  endgroup

  cg cov = new;
  control_cg control = new;
  int covered, total;
  real coverage;

  initial begin
    cov.sample(0); cov.sample(1); cov.sample(2); cov.sample(3);
    control.sample(0); control.sample(1); control.sample(2); control.sample(3);
    coverage = cov.get_inst_coverage(covered, total);
    if (coverage != 0.0 || covered != 0 || total != 1)
      $fatal(1, "illegal overlap bin not removed: %0.1f %0d/%0d",
             coverage, covered, total);
    if (control.get_inst_coverage() != 50.0)
      $fatal(1, "control coverage changed: %0.1f",
             control.get_inst_coverage());
    $display("illegal transition overlap removed");
    $finish;
  end
endmodule
