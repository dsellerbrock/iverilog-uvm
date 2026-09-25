// An unknown four-state method result must fail at construction.
module top;
  class reg_c;
    const logic [3:0] offset;
    function new(); offset = 4'bxxxx; endfunction
    function automatic logic [3:0] get_offset(); return offset; endfunction
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
    reg_arg = new;
    wrapper = new(reg_arg);
    $fatal(1, "unknown endpoint did not stop construction");
  end
endmodule
