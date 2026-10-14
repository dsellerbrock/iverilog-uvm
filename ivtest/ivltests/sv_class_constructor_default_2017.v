module test;
  class Base;
    function new(int value);
    endfunction
  endclass

  class Derived extends Base;
    function new(default);
    endfunction
  endclass
endmodule
