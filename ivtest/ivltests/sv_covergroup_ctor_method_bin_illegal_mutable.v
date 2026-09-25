// IEEE 1800-2017/2023 19.5: a mutable enclosing-class property cannot
// supply a bin expression, including through a selected method path.
module top;
  class reg_c;
    const int offset;
    function new(int value); offset = value; endfunction
    function automatic int get_offset(); return offset; endfunction
  endclass
  class wrapper_c;
    reg_c status;
    covergroup cg with function sample(int offset);
      cp: coverpoint offset {
        bins illegal = {status.get_offset()};
      }
    endgroup
  endclass
endmodule
