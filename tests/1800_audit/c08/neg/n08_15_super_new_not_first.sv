class A; function new(int value); endfunction endclass
class B extends A;
  int value;
  function new(); value = 1; super.new(2); endfunction
endclass
module top; endmodule
