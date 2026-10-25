// IEEE 1800-2023 §8.20 Example 3: :initial on a virtual override.
class BaseN4;
  virtual function void f2(); endfunction
endclass
class DerivedN4 extends BaseN4;
  function :initial void f2(); endfunction
endclass
module p08_20_spec_n4;
endmodule
