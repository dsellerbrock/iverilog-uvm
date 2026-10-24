module sv_covergroup_inst_coverage_counts;
  bit [1:0] value;

  covergroup three_bins;
    option.get_inst_coverage = 1;
    cp: coverpoint value {
      bins low = {0};
      bins middle = {1};
      bins high = {2, 3};
    }
  endgroup

  covergroup no_items;
    option.get_inst_coverage = 1;
  endgroup

  covergroup zero_weight;
    option.get_inst_coverage = 1;
    cp: coverpoint value {
      option.weight = 0;
      bins all_values[] = {[0:3]};
    }
  endgroup

  three_bins sampled = new;
  no_items empty = new;
  zero_weight unweighted = new;
  int covered, total;

  initial begin
    value = 0;
    sampled.sample();
    covered = 99;
    total = 99;
    if (sampled.get_inst_coverage(covered, total) != 100.0/3.0
        || covered != 1 || total != 3)
      $fatal(1, "expected 1/3 bins, got %0d/%0d", covered, total);
    $display("sampled bins=%0d/%0d", covered, total);

    covered = 99;
    total = 99;
    if (empty.get_inst_coverage(covered, total) != 0.0
        || covered != 0 || total != 0)
      $fatal(1, "zero denominator must assign 0/0, got %0d/%0d",
             covered, total);
    $display("empty bins=%0d/%0d", covered, total);

    covered = 99;
    total = 99;
    if (unweighted.get_inst_coverage(covered, total) != 0.0
        || covered != 0 || total != 0)
      $fatal(1, "zero-weight denominator must assign 0/0, got %0d/%0d",
             covered, total);
    $display("zero-weight bins=%0d/%0d", covered, total);
    $finish;
  end
endmodule
