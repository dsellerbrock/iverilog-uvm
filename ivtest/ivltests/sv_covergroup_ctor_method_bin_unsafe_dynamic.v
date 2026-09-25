// Even compatibility mode must reject an unproven selected receiver index.
module top;
  class reg_c;
    const int offset;
    function new(int value); offset = value; endfunction
    function automatic int get_offset(); return offset; endfunction
  endclass
  class block_c;
    reg_c err[2];
    function new(); err[0] = new(4); err[1] = new(8); endfunction
  endclass
  class wrapper_c;
    covergroup cg(block_c ral, int idx) with function sample(int value);
      cp: coverpoint value { bins selected = {ral.err[idx].get_offset()}; }
    endgroup
    function new(block_c arg, int idx); cg = new(arg, idx); endfunction
  endclass
  block_c block_arg;
  wrapper_c wrapper;
  initial begin
    block_arg = new;
    wrapper = new(block_arg, 0);
  end
endmodule
