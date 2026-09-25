// A huge unsigned selector must not wrap into a valid negative array index.
module top;
  class reg_c;
    const int offset;
    function new(int value); offset = value; endfunction
    function automatic int get_offset(); return offset; endfunction
  endclass
  class block_c;
    reg_c err[-1:0];
    function new(); err[-1] = new(4); err[0] = new(8); endfunction
  endclass
  class wrapper_c;
    covergroup cg(block_c ral) with function sample(int value);
      cp: coverpoint value {
        bins selected = {ral.err[64'hffff_ffff_ffff_ffff].get_offset()};
      }
    endgroup
    function new(block_c arg); cg = new(arg); endfunction
  endclass
  block_c block_arg;
  wrapper_c wrapper;
  initial begin
    block_arg = new;
    wrapper = new(block_arg);
  end
endmodule
