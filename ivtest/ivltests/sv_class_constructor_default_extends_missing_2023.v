module test;
  class Base;
    function new(int value);
    endfunction
  endclass

  class Derived extends Base(default);
    function new(int value);
    endfunction
  endclass
endmodule
