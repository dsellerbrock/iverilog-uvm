// IEEE 1800-2017/2023 19.5.3: wide integral automatic bins are uniform.
// The member covergroup reproduces #667; the formal group checks bin routing.
module top;
  class result_transaction;
    bit [511:0] result;
  endclass

  class property_coverage;
    result_transaction coverage_trans;
    covergroup result_cg;
      option.auto_bin_max = 1024;
      result: coverpoint coverage_trans.result;
    endgroup

    function new();
      coverage_trans = new();
      result_cg = new();
    endfunction
  endclass

  covergroup wide_cg with function sample(bit [511:0] value, bit enable);
    option.per_instance = 1;
    option.auto_bin_max = 1024;
    cp: coverpoint value;
    en: coverpoint enable;
    cx: cross cp, en;
  endgroup

  property_coverage property_cg = new;
  wide_cg cg = new;

  initial begin
    property_cg.result_cg.sample();
    cg.sample(512'h0, 0);
    cg.sample(512'h3ff, 0); // Same automatic bin: only bits [511:502] select a bin.
    cg.sample(512'h1 << 502, 0);
    cg.sample(512'h1 << 511, 1);
    cg.sample({512{1'b1}}, 1);
    if (cg.cp.get_inst_coverage() < 0.3905 ||
        cg.cp.get_inst_coverage() > 0.3908)
      $fatal(1, "wide automatic bins were not partitioned by the high bits: %f",
             cg.cp.get_inst_coverage());
    if (cg.cx.get_inst_coverage() < 0.1952 ||
        cg.cx.get_inst_coverage() > 0.1955)
      $fatal(1, "wide automatic bins were not retained in cross bins: %f",
             cg.cx.get_inst_coverage());
    $display("PASSED");
  end
endmodule
