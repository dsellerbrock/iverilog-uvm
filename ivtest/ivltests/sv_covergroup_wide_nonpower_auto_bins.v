// IEEE 1800-2017/2023 19.5.3: automatic bins support arbitrary counts.
module top;
  covergroup cg with function sample(bit [511:0] value);
    option.auto_bin_max = 3;
    cp: coverpoint value;
  endgroup

  cg cov = new;

  initial begin
    cov.sample(512'h0);
    cov.sample(512'h1 << 511);
    cov.sample({512{1'b1}});
    if (cov.get_inst_coverage() != 100.0)
      $fatal(1, "expected all three wide automatic bins to be covered");
    $display("PASSED");
  end
endmodule
