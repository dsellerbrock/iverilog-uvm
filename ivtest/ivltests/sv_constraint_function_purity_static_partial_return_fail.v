package purity_static_partial_return_pkg;
  // Only one bit is overwritten; all other return bits retain prior state.
  function int partial();
    partial[0] = 0;
  endfunction
endpackage
class purity_static_partial_return_fail;
  rand int value;
  constraint c { value == purity_static_partial_return_pkg::partial(); }
endclass
module test;
  purity_static_partial_return_fail item;
  initial begin
    item = new;
    void'(item.randomize());
  end
endmodule
