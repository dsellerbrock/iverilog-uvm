// A literal omitted method argument is captured with the endpoint.
module top;
  class reg_c;
    const int offset;
    function new(int value); offset = value; endfunction
    function automatic int get_offset(int delta = 2);
      return offset + delta;
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
    wrapper.cg.sample(16);
    if (wrapper.cg.get_inst_coverage() != 0.0)
      $fatal(1, "omitted literal default was ignored");
    wrapper.cg.sample(18);
    if (wrapper.cg.get_inst_coverage() != 100.0)
      $fatal(1, "literal default endpoint was dropped");
    $display("PASSED");
  end
endmodule
