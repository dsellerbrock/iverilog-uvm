module test;
  class Base;
    function new(int value);
    endfunction
  endclass

  class Derived extends Base(default);
    function new(default);
      super.new(default);
    endfunction
  endclass
endmodule
