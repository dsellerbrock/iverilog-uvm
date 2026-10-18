class A; int value; function new(int value); this.value = value; endfunction endclass
class B extends A(1);
  function new(); super.new(2); endfunction
endclass
module top;
  B b;
  initial begin b = new; $display("value=%0d", b.value); end
endmodule
