// IEEE 1800-2017/2023 8.23: nested classes have no implicit outer `this'.
class outer_c;
  int outerProp = 6;
  class inner_c;
    function void innerMethod(); outerProp = 0; endfunction
  endclass
endclass

module test;
  outer_c::inner_c inner;
  initial begin
    inner = new;
    inner.innerMethod();
  end
endmodule
