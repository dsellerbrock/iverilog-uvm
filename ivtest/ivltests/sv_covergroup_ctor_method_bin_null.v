// A null selected receiver must fail at construction, before a false zero bin.
module top;
  class reg_c;
    const int offset;
    function new(int value); offset = value; endfunction
    function automatic int get_offset(); return offset; endfunction
  endclass
  class wrapper_c;
    covergroup cg(reg_c reg_arg) with function sample(int value);
      cp: coverpoint value { bins selected = {reg_arg.get_offset()}; }
    endgroup
    function new(reg_c arg); cg = new(arg); endfunction
  endclass
  reg_c reg_arg;
  wrapper_c wrapper;
  initial begin
    reg_arg = null;
    wrapper = new(reg_arg);
    $fatal(1, "null receiver did not stop construction");
  end
endmodule
