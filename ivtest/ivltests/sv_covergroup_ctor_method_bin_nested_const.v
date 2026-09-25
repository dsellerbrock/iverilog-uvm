// A nested const handle needs proof beyond the direct-formal path.
module top;
  class reg_c;
    const int offset;
    function new(int value); offset = value; endfunction
    function automatic int get_offset(); return offset; endfunction
  endclass
  class block_c;
    const reg_c child;
    function new(int value); child = new(value); endfunction
  endclass
  class wrapper_c;
    covergroup cg(block_c block_arg) with function sample(int value);
      cp: coverpoint value {
        bins unsupported = {block_arg.child.get_offset()};
      }
    endgroup
  endclass
endmodule
