// IEEE 1800-2017/2023 19.5: preserve a narrow signed method result.
module top;
  class reg_c;
    const logic signed [7:0] offset;
    function new(logic signed [7:0] value); offset = value; endfunction
    function automatic logic signed [7:0] get_offset();
      return offset;
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
    reg_arg = new(-3);
    wrapper = new(reg_arg);
    wrapper.cg.sample(253);
    if (wrapper.cg.get_inst_coverage() != 0.0)
      $fatal(1, "narrow signed endpoint was treated as unsigned");
    wrapper.cg.sample(-3);
    if (wrapper.cg.get_inst_coverage() != 100.0)
      $fatal(1, "narrow signed endpoint was dropped");
    $display("PASSED");
  end
endmodule
