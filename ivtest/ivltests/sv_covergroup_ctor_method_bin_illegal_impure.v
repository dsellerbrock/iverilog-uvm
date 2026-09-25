// IEEE 1800-2017/2023 19.5: a method reading mutable state is not a
// covergroup_expression even through a non-ref constructor formal.
module top;
  class reg_c;
    int offset;
    function new(int value); offset = value; endfunction
    function automatic int get_offset(); return offset; endfunction
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
    reg_arg = new(7);
    wrapper = new(reg_arg);
  end
endmodule
