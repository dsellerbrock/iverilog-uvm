interface virtual_sample_if;
  logic value;
  covergroup cg;
    option.per_instance = 1;
    cp: coverpoint value { bins zero = {0}; bins one = {1}; }
  endgroup
  cg cov = new;
  covergroup shifted_cg;
    option.per_instance = 1;
    cp: coverpoint value + 1 { bins one = {1}; bins two = {2}; }
  endgroup
  shifted_cg shifted_cov = new;
endinterface

module test;
  virtual_sample_if u0();
  virtual_sample_if u1();
  virtual virtual_sample_if vif;
  bit failed = 0;

  task check(string label, real got, real expected);
    if (got != expected) begin
      $display("FAILED -- %0s: got %f, expected %f", label, got, expected);
      failed = 1;
    end
  endtask

  initial begin
    u0.value = 0;
    u0.cov.sample();
    check("physical control", u0.cov.get_inst_coverage(), 50.0);
    u0.shifted_cov.sample();
    check("physical expression control", u0.shifted_cov.get_inst_coverage(), 50.0);

    vif = u1;
    u1.value = 0;
    vif.cov.sample();
    check("virtual u1 first bin", u1.cov.get_inst_coverage(), 50.0);
    vif.shifted_cov.sample();
    check("virtual expression u1 first bin", u1.shifted_cov.get_inst_coverage(), 50.0);

    vif = u0;
    u0.value = 1;
    vif.cov.sample();
    vif.shifted_cov.sample();
    check("rebound u0", u0.cov.get_inst_coverage(), 100.0);
    check("rebound expression u0", u0.shifted_cov.get_inst_coverage(), 100.0);
    check("u1 remains isolated", u1.cov.get_inst_coverage(), 50.0);
    check("expression u1 remains isolated", u1.shifted_cov.get_inst_coverage(), 50.0);

    vif = u1;
    u1.value = 1;
    vif.cov.sample();
    vif.shifted_cov.sample();
    check("rebound u1", u1.cov.get_inst_coverage(), 100.0);
    check("rebound expression u1", u1.shifted_cov.get_inst_coverage(), 100.0);

    if (failed) $fatal(1, "virtual-interface covergroup sampling failed");
    $display("PASSED");
  end
endmodule
