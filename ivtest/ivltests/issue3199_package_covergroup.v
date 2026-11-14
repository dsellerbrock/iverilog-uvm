package coverage_pkg;
  covergroup cg_t with function sample(int x);
    cp: coverpoint x { bins values[] = {0, 1, 2, 3}; }
  endgroup
  cg_t first, second;
endpackage

module issue3199_package_covergroup;
  import coverage_pkg::second;
  initial begin
    coverage_pkg::first = new;
    second = new;
    coverage_pkg::first.sample(0);
    coverage_pkg::first.sample(1);
    second.sample(2);
    if (coverage_pkg::first.get_inst_coverage() != 50.0 ||
        second.get_inst_coverage() != 25.0) begin
      $display("FAILED");
      $fatal(1);
    end
    $display("PASSED");
  end
endmodule
