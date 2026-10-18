class A; function new(int value); endfunction endclass
class B extends A;
  function new(int value); super.new(default); endfunction
endclass
module top; endmodule
