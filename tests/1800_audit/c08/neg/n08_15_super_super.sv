class A;
  int count;
endclass
class B extends A;
  function int bad(); return super.super.count; endfunction
endclass
module top; endmodule
