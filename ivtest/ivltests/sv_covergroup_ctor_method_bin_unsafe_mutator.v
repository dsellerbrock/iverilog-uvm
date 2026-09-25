// The opt-in unsafe path exposes a side-effecting getter as nonstandard.
module top;
  class reg_c;
    const int offset;
    int calls;
    function new(int value); offset = value; calls = 0; endfunction
    function automatic int get_offset();
      calls++;
      return offset;
    endfunction
  endclass
  class wrapper_c;
    covergroup cg(reg_c reg_arg) with function sample(int value);
      option.per_instance = 1;
      cp: coverpoint value { bins selected = {reg_arg.get_offset()}; }
    endgroup
    function new(reg_c arg); cg = new(arg); endfunction
  endclass
  reg_c reg_arg;
  wrapper_c wrapper;
  initial begin
    reg_arg = new(16);
    wrapper = new(reg_arg);
    if (reg_arg.calls != 1)
      $fatal(1, "unsafe endpoint was not evaluated exactly once");
    wrapper.cg.sample(16);
    if (reg_arg.calls != 1 || wrapper.cg.get_inst_coverage() != 100.0)
      $fatal(1, "unsafe endpoint was re-evaluated at sample time");
    $display("PASSED");
  end
endmodule
