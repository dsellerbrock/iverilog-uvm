// IEEE 1800-2017/2023 19.5: a ref covergroup argument cannot supply
// a bin expression, including through a selected class method path.
module top;
  class reg_c;
    const int offset;
    function new(int value); offset = value; endfunction
    function automatic int get_offset(); return offset; endfunction
  endclass
  class block_c;
    reg_c status;
    function new(); status = new(4); endfunction
  endclass
  class wrapper_c;
    covergroup cg(ref block_c ral) with function sample(int offset);
      cp: coverpoint offset {
        bins illegal = {ral.status.get_offset()};
      }
    endgroup
  endclass
endmodule
