// Strict IEEE 1800 19.5 must not overlook an omitted mutable default.
module top;
  class reg_c;
    const int offset;
    int extra;
    function new(int value); offset = value; extra = 3; endfunction
    function automatic int get_extra(); return extra; endfunction
    function automatic int get_offset(int delta = get_extra());
      return offset + delta;
    endfunction
  endclass
  class wrapper_c;
    covergroup cg(reg_c reg_arg) with function sample(int value);
      cp: coverpoint value { bins illegal = {reg_arg.get_offset()}; }
    endgroup
    function new(reg_c arg); cg = new(arg); endfunction
  endclass
  reg_c reg_arg;
  wrapper_c wrapper;
  initial begin
    reg_arg = new(16);
    wrapper = new(reg_arg);
  end
endmodule
