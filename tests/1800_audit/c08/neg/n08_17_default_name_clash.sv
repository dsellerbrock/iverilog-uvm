class A; function new(int key); endfunction endclass
class B extends A;
  function new(int key, default); super.new(default); endfunction
endclass
module top; endmodule
