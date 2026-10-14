module test;
  class Base;
    local int value;
    function new(int arg = value);
    endfunction
  endclass

  class Derived extends Base;
    function new(default);
    endfunction
  endclass
endmodule
