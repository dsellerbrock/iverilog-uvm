package purity_static_missing_return_pkg;
  // A false input falls through and would reuse the persistent return value.
  function int maybe_one(input int enabled);
    if (enabled) return 1;
  endfunction
endpackage
class purity_static_missing_return_fail;
  rand int value;
  constraint c { value == purity_static_missing_return_pkg::maybe_one(0); }
endclass
module test;
  purity_static_missing_return_fail item;
  initial begin
    item = new;
    void'(item.randomize());
  end
endmodule
