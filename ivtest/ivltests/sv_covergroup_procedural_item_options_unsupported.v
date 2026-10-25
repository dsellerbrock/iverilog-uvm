// Nonexistent option members remain invalid in procedural access.
class unsupported_item_option_wrap;
  covergroup cg with function sample(bit value);
    cp: coverpoint value { bins one = {1}; }
  endgroup

  function new;
    cg = new;
  endfunction
endclass

module main;
  unsupported_item_option_wrap wrapper;
  int sink;

  initial begin
    wrapper = new;
    sink = wrapper.cg.cp.option.bogus;
    wrapper.cg.cp.option.bogus = 1;
    wrapper.cg.option.per_instance = 1;
    wrapper.cg.cp.option.auto_bin_max = 128;
    wrapper.cg.cp.option.detect_overlap = 1;
  end
endmodule
