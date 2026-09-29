class wide_array_cov;
  covergroup mod_cg with function sample(logic [255:0] mod_value);
    cp: coverpoint mod_value { bins extremes[] = {'0, '1}; }
  endgroup

  covergroup pair_cg with function sample(logic [127:0] mnemonic, bit sel);
    cp: coverpoint mnemonic {
      bins low = {128'h1};
      bins high = {128'h1_0000_0000_0000_0001};
    }
    s: coverpoint sel { bins one = {1}; }
    pair: cross cp, s {
      ignore_bins lower = binsof(cp.low);
      bins selected = binsof(cp.high) && binsof(s.one);
    }
  endgroup

  function new();
    mod_cg = new;
    pair_cg = new;
  endfunction
endclass

module top;
  wide_array_cov cov;
  logic [255:0] all_ones;
  initial begin
    cov = new;
    all_ones = '1;
    cov.mod_cg.sample(256'h1);
    if (cov.mod_cg.get_inst_coverage() != 0)
      $fatal(1, "wide '1 array bin aliased literal 1");
    cov.mod_cg.sample('0);
    if (cov.mod_cg.get_inst_coverage() != 50)
      $fatal(1, "wide zero array bin missing");
    cov.mod_cg.sample(all_ones);
    if (cov.mod_cg.get_inst_coverage() != 100)
      $fatal(1, "wide fill-one array bin missing");
    cov.pair_cg.sample(128'h2_0000_0000_0000_0001, 1);
    if (cov.pair_cg.cp.get_inst_coverage() != 0 ||
        cov.pair_cg.pair.get_inst_coverage() != 0)
      $fatal(1, "named cross matched a high-bit alias");
    cov.pair_cg.sample(128'h1, 1);
    if (cov.pair_cg.pair.get_inst_coverage() != 0)
      $fatal(1, "named cross matched the low choice");
    cov.pair_cg.sample(128'h1_0000_0000_0000_0001, 1);
    if (cov.pair_cg.pair.get_inst_coverage() != 100)
      $fatal(1, "named cross missed the high choice");
    $display("PASS wide array and named cross");
  end
endmodule
