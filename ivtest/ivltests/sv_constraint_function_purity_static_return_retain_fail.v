package purity_static_return_retain_pkg;
  // Package subroutines have static lifetime unless declared automatic.
  function int counter();
    counter = counter + 1;
  endfunction
endpackage
class purity_static_return_retain_fail;
  rand int value;
  constraint c { value == purity_static_return_retain_pkg::counter(); }
endclass
module test;
  purity_static_return_retain_fail item;
  initial begin
    item = new;
    void'(item.randomize());
  end
endmodule
