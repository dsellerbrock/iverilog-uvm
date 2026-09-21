class receiver_pure_base;
  virtual function int read(); return 7; endfunction
endclass
class receiver_impure_derived extends receiver_pure_base;
  int state;
  virtual function int read();
    state++;
    return state;
  endfunction
endclass
class receiver_purity_item;
  rand int result;
  receiver_pure_base state;
  constraint c { result == state.read(); }
endclass
module test;
  receiver_purity_item value;
  initial begin
    value = new;
    void'(value.randomize());
  end
endmodule
