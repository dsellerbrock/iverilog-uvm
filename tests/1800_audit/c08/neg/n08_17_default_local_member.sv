class A;
  local int seed = 3;
  function new(int value = seed); endfunction
endclass
class B extends A;
  function new(default); super.new(default); endfunction
endclass
module top; endmodule
