// IEEE 1800-2017/2023 19.5.1: a fixed-size bin array is partitioned
// before ignore_bins and illegal_bins remove values. Removing a value must
// not repartition the remaining values or change the number of split bins.
module top;
  function automatic bit near(real got, real want);
    return got > want - 0.01 && got < want + 0.01;
  endfunction

  covergroup cg with function sample(int value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins split[4] = {[1:13]};
      ignore_bins carve = {1};
    }
  endgroup

  cg cov = new;

  initial begin
    // The first partition remains [1:3], then value 1 is carved from it.
    cov.sample(2);
    if (!near(cov.get_inst_coverage(), 25.0))
      $fatal(1, "ignore bin was applied before fixed-bin distribution");

    // Value 4 belongs to the unchanged second partition [4:6].
    cov.sample(4);
    if (!near(cov.get_inst_coverage(), 50.0))
      $fatal(1, "post-distribution carve changed fixed-bin identity");

    $display("PASSED");
    $finish;
  end
endmodule
