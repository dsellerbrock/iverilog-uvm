typedef logic [127:0] mnem_t;
typedef logic [159:0] csr_t;

class wide_cov;
  localparam mnem_t short_name = mnem_t'("add");
  localparam mnem_t long_name = mnem_t'("bn.mulqacc.wo");
  localparam csr_t csr_name = csr_t'("load_checksum");

  covergroup pair_cg with function sample(mnem_t mnemonic, bit selector);
    cp_m: coverpoint mnemonic {
      bins short_bin = {short_name};
      bins long_bin = {long_name};
    }
    cp_s: coverpoint selector {
      bins zero = {0};
      bins one = {1};
    }
    pair: cross cp_m, cp_s;
  endgroup

  covergroup csr_cg with function sample(csr_t csr, bit selector);
    cp: coverpoint csr { bins load_checksum = {csr_name}; }
    sel: coverpoint selector { bins zero = {0}; bins one = {1}; }
    pair: cross cp, sel;
  endgroup

  function new();
    pair_cg = new;
    csr_cg = new;
  endfunction
endclass

module top;
  wide_cov cov;
  mnem_t unknown_name;
  initial begin
    cov = new;
    cov.pair_cg.sample(mnem_t'("add") | (mnem_t'(1) << 80), 0);
    if (cov.pair_cg.cp_m.get_inst_coverage() != 0 ||
        cov.pair_cg.pair.get_inst_coverage() != 0)
      $fatal(1, "high-bit alias matched a 128-bit bin or cross");
    unknown_name = mnem_t'("add");
    unknown_name[80] = 1'bx;
    cov.pair_cg.sample(unknown_name, 0);
    if (cov.pair_cg.cp_m.get_inst_coverage() != 0 ||
        cov.pair_cg.pair.get_inst_coverage() != 0)
      $fatal(1, "X bit matched a 128-bit bin or cross");
    cov.pair_cg.sample(mnem_t'("add"), 0);
    if (cov.pair_cg.get_inst_coverage() < 41.66 ||
        cov.pair_cg.get_inst_coverage() > 41.67)
      $fatal(1, "first 128-bit cross tuple missing");
    cov.pair_cg.sample(mnem_t'("add"), 1);
    cov.pair_cg.sample(mnem_t'("bn.mulqacc.wo"), 0);
    cov.pair_cg.sample(mnem_t'("bn.mulqacc.wo"), 1);
    if (cov.pair_cg.get_inst_coverage() != 100)
      $fatal(1, "128-bit cross tuples incomplete");
    cov.csr_cg.sample(csr_t'("load_checksum") | (csr_t'(1) << 130), 0);
    if (cov.csr_cg.cp.get_inst_coverage() != 0 ||
        cov.csr_cg.pair.get_inst_coverage() != 0)
      $fatal(1, "high-bit alias matched a 160-bit bin or cross");
    cov.csr_cg.sample(csr_t'("load_checksum"), 0);
    cov.csr_cg.sample(csr_t'("load_checksum"), 1);
    if (cov.csr_cg.get_inst_coverage() != 100)
      $fatal(1, "160-bit cross tuples incomplete");
    $display("PASS wide exact cross");
  end
endmodule
