module test;
  class Base;
    function new(int value);
    endfunction
  endclass

  class Derived extends Base;
    function new(default, int value);
    endfunction
  endclass
endmodule
