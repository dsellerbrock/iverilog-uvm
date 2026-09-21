module test;
  bit [2:0] probe;
  covergroup cg with function sample(bit [2:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins selected = {[0:7]} with (item inside {[-1:3]});
      bins anchor = {7};
    }
  endgroup
  cg c;
  initial begin
    c = new;
    probe = 0;
    if (probe inside {[-1:3]}) $fatal(1, "ordinary inside comparison oracle");
    c.sample(0);
    if (c.get_inst_coverage() != 0.0) $fatal(1, "inside filter included zero: %f", c.get_inst_coverage());
    c.sample(7);
    if (c.get_inst_coverage() != 100.0) $fatal(1, "empty filter denominator: %f", c.get_inst_coverage());
    $display("PASSED");
  end
endmodule
