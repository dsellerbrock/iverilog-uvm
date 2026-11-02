// IEEE 1800-2017/2023 19.5.1: explicit value ranges are legal for wide bins.
module top;
  covergroup cg with function sample(input bit [255:0] value);
    cp: coverpoint value {
      bins full = {[256'h0:
        256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff]};
      bins span = {[256'h000000000000000000000000000000000000000000000000ffffffffffffffff:
                    256'h0000000000000000000000000000000000000000000000010000000000000001]};
    }
  endgroup

  cg coverage = new();

  initial begin
    coverage.sample('0);
    if (coverage.cp.get_inst_coverage() != 50)
      $fatal(1, "full wide explicit range did not match");
    coverage.sample(256'h000000000000000000000000000000000000000000000000fffffffffffffffe);
    coverage.sample(256'h0000000000000000000000000000000000000000000000010000000000000002);
    if (coverage.cp.get_inst_coverage() != 50)
      $fatal(1, "wide range matched below its lower bound");
    coverage.sample(256'h000000000000000000000000000000000000000000000000ffffffffffffffff);
    coverage.sample(256'h0000000000000000000000000000000000000000000000010000000000000001);
    if (coverage.cp.get_inst_coverage() != 100)
      $fatal(1, "wide range did not match both cross-word inclusive bounds");
    $display("PASSED");
  end
endmodule
