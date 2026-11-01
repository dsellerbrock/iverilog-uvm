// IEEE 1800-2017/2023 19.5.5: a covered transition sequence that contains
// an ignored sequence is removed, leaving its bin out of the denominator.
module test;
  covergroup cg with function sample(int v);
    option.per_instance = 1;
    cp: coverpoint v {
      bins start = (10 => 11 => 12);
      bins middle = (20 => 21 => 22 => 23);
      bins ending = (30 => 31 => 32);
      bins separate = (40 => 41 => 42);
      ignore_bins ignore_start = (10 => 11);
      ignore_bins ignore_middle = (21 => 22);
      ignore_bins ignore_ending = (31 => 32);
      ignore_bins ignore_separate = (50 => 51);
    }
  endgroup
  cg c = new;
  real cov;
  initial begin
    c.sample(10); c.sample(11); c.sample(12);
    c.sample(20); c.sample(21); c.sample(22); c.sample(23);
    c.sample(30); c.sample(31); c.sample(32);
    cov = c.get_inst_coverage();
    if (cov != 0.0)
      $fatal(1, "contained sequences remain in coverage: %0.2f", cov);
    c.sample(40); c.sample(41); c.sample(42);
    cov = c.get_inst_coverage();
    if (cov != 100.0)
      $fatal(1, "unmatched sequence was not counted: %0.2f", cov);
    $display("PASSED");
  end
endmodule
