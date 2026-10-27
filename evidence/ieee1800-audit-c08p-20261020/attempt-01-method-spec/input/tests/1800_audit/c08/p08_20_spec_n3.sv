// IEEE 1800-2023 §8.20 Example 3: overriding a :final non-virtual method.
class A3;
  function :final void f4(); endfunction
endclass
class B3 extends A3;
  function void f4(); endfunction
endclass
module p08_20_spec_n3;
endmodule
