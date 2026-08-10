// The keyed unique result retains the receiver's concrete class element type.
class callback_base;
  virtual function int get_inst_id();
    return 1;
  endfunction
endclass

class unrelated;
endclass

module main;
  callback_base source[$];
  unrelated wrong[$];

  initial
    wrong = source.unique(cb_) with (cb_.get_inst_id);
endmodule
