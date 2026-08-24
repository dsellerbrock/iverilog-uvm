// IEEE 1800-2023 19.7.1 defines more per-item options than this bounded
// implementation currently models. Recognized item-option hierarchy must
// fail loudly instead of collapsing reads to zero or dropping writes.
class unsupported_declaration_at_least_wrap;
  covergroup cg(int threshold) with function sample(bit value);
    cp: coverpoint value {
      option.at_least = threshold;
      bins one = {1};
    }
  endgroup

  function new(int threshold);
    cg = new(threshold);
  endfunction
endclass

class unsupported_item_option_wrap;
  covergroup cg with function sample(bit value);
    cp: coverpoint value {
      bins one = {1};
    }
  endgroup

  function new;
    cg = new;
  endfunction
endclass

module main;
  unsupported_declaration_at_least_wrap threshold_wrapper;
  unsupported_item_option_wrap wrapper;
  int sink; string text_sink;

  initial begin
    threshold_wrapper = new(2);
    wrapper = new;
    sink = wrapper.cg.cp.option.goal;
    text_sink = wrapper.cg.cp.option.comment;
    sink = wrapper.cg.cp.option.bogus;
    wrapper.cg.cp.option.goal = 50;
    wrapper.cg.cp.option.comment = "changed";
    wrapper.cg.cp.option.bogus = 1;
  end
endmodule
