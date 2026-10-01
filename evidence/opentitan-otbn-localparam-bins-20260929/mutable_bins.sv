module top;
  typedef bit [16*8-1:0] mnem_str_t;
  typedef bit [20*8-1:0] csr_str_t;

  class cov;
`ifdef CONST_FIELDS
`define FIELD_CONST const
`else
`define FIELD_CONST
`endif
`define DEF_MNEM(NAME, TEXT) `FIELD_CONST mnem_str_t NAME = mnem_str_t'(TEXT)
`define DEF_CSR(NAME, TEXT) `FIELD_CONST csr_str_t NAME = csr_str_t'(TEXT)
    `DEF_MNEM(mnem_add, "add");
    `DEF_CSR(csr_load_checksum, "load_checksum");
`undef DEF_MNEM
`undef DEF_CSR
`undef FIELD_CONST

    covergroup cg with function sample(mnem_str_t mnemonic, csr_str_t csr);
      option.per_instance = 1;
      mnemonic_cp: coverpoint mnemonic { bins add = {mnem_add}; }
      csr_cp: coverpoint csr { bins load_checksum = {csr_load_checksum}; }
    endgroup

    function new;
      cg = new;
    endfunction
  endclass

  initial begin
    cov c = new;
    c.cg.sample(mnem_str_t'("add"), csr_str_t'("load_checksum"));
    if (c.cg.get_inst_coverage() != 100.0)
      $fatal(1, "OTBN packed coverage bin was dropped");
    $display("PASS OTBN packed coverage bins");
  end
endmodule
