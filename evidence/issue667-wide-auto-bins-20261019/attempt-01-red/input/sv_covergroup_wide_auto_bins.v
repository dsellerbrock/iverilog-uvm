// IEEE 1800-2017/2023 19.5.3: wide integral automatic bins are uniform.
// A sample() formal isolates bin representation from class-property sampling.
module test;
  covergroup wide_cg with function sample(bit [511:0] value);
    option.per_instance = 1;
    option.auto_bin_max = 1024;
    cp: coverpoint value;
  endgroup

  wide_cg cg = new;

  initial begin
    cg.sample(512'h0);
    cg.sample(512'h3ff); // Same automatic bin: only bits [511:502] select a bin.
    cg.sample(512'h1 << 502);
    cg.sample(512'h1 << 511);
    cg.sample({512{1'b1}});
    if (cg.cp.get_inst_coverage() < 0.3905 ||
        cg.cp.get_inst_coverage() > 0.3908)
      $fatal(1, "wide automatic bins were not partitioned by the high bits: %f",
             cg.cp.get_inst_coverage());
    $display("PASS wide automatic bins");
  end
endmodule
