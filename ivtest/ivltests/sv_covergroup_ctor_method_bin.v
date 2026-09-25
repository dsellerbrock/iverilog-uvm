// IEEE 1800-2017/2023 19.3, 19.5: a pure method through a non-ref
// constructor formal supplies one construction-time bin endpoint.
module top;
  class reg_c;
    const int offset;
    function new(int value); offset = value; endfunction
    function automatic int get_offset(); return offset; endfunction
  endclass
  class wrapper_c;
    covergroup cg(reg_c reg_arg) with function sample(int offset);
      option.per_instance = 1;
      cp: coverpoint offset { bins selected = {reg_arg.get_offset()}; }
    endgroup
    function new(reg_c arg); cg = new(arg); endfunction
  endclass
  reg_c a, b;
  wrapper_c wa, wb;
  initial begin
    a = new(16);
    b = new(48);
    wa = new(a);
    wb = new(b);
    a = new(99);
    wa.cg.sample(99);
    if (wa.cg.get_inst_coverage() != 0.0)
      $fatal(1, "endpoint followed the caller handle after construction");
    wb.cg.sample(16);
    if (wb.cg.get_inst_coverage() != 0.0)
      $fatal(1, "endpoint leaked from another covergroup instance");
    wa.cg.sample(16);
    wb.cg.sample(48);
    if (wa.cg.get_inst_coverage() != 100.0 ||
        wb.cg.get_inst_coverage() != 100.0)
      $fatal(1, "per-instance method endpoints were not captured");
    $display("PASSED");
  end
endmodule
