// Explicit -gcommercial-unsafe compatibility: nested mutable class handles
// are captured at covergroup construction.
module top;
  class reg_c;
    const int offset;
    function new(int value); offset = value; endfunction
    function automatic int get_offset(); return offset; endfunction
  endclass
  class block_c;
    reg_c status;
    reg_c err[2];
    function new(int base);
      status = new(base);
      err[0] = new(base + 4);
      err[1] = new(base + 8);
    endfunction
  endclass
  class wrapper_c;
    covergroup cg(block_c ral) with function sample(int offset);
      option.per_instance = 1;
      cp: coverpoint offset {
        bins status = {ral.status.get_offset()};
        bins err0 = {ral.err[0].get_offset()};
        bins err1 = {ral.err[1].get_offset()};
      }
    endgroup
    function new(block_c arg); cg = new(arg); endfunction
  endclass
  block_c a, b;
  wrapper_c wa, wb;
  initial begin
    a = new(16);
    b = new(48);
    wa = new(a);
    wb = new(b);
    a.status = new(99);
    a.err[0] = new(100);
    wa.cg.sample(99);
    if (wa.cg.get_inst_coverage() != 0.0)
      $fatal(1, "endpoint was re-evaluated after construction");
    wa.cg.sample(16);
    wa.cg.sample(20);
    if (wa.cg.get_inst_coverage() >= 100.0)
      $fatal(1, "err[1] endpoint was dropped before its value was sampled");
    wa.cg.sample(24);
    wb.cg.sample(48);
    wb.cg.sample(52);
    if (wb.cg.get_inst_coverage() >= 100.0)
      $fatal(1, "second instance's err[1] endpoint was dropped");
    wb.cg.sample(56);
    if (wa.cg.get_inst_coverage() != 100.0 ||
        wb.cg.get_inst_coverage() != 100.0)
      $fatal(1, "nested endpoints were not captured per instance");
    $display("PASSED");
  end
endmodule
