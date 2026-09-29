package otbn_tiny_pkg;
  typedef bit [16*8-1:0] mnem_str_t;
  typedef bit [20*8-1:0] csr_str_t;

  class cov;
`define DEF_MNEM(NAME, TEXT) localparam mnem_str_t NAME = mnem_str_t'(TEXT)
`define DEF_CSR(NAME, TEXT) localparam csr_str_t NAME = csr_str_t'(TEXT)
    `DEF_MNEM(mnem_add, "add");
    `DEF_CSR(csr_load_checksum, "load_checksum");
`undef DEF_MNEM
`undef DEF_CSR

    covergroup cg with function sample(mnem_str_t mnemonic, csr_str_t csr);
      option.per_instance = 1;
      mnemonic_cp: coverpoint mnemonic { bins add = {mnem_add}; }
      csr_cp: coverpoint csr { bins load_checksum = {csr_load_checksum}; }
    endgroup

    function new;
      cg = new;
    endfunction
  endclass
endpackage

module top;
  import otbn_tiny_pkg::*;
  initial begin
    cov c;
    c = new;
    c.cg.sample(mnem_str_t'("add"), csr_str_t'("load_checksum"));
    if (c.cg.get_inst_coverage() != 100.0)
      $fatal(1, "OTBN packed coverage bin was dropped");
    $display("PASS OTBN package packed coverage bins");
  end
endmodule
