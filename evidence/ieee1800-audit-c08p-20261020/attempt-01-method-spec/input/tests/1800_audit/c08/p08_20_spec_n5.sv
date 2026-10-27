// IEEE 1800-2023 §8.20 Example 3: :initial on a pure-virtual override.
virtual class BaseN5;
  pure virtual function void f3();
endclass
class DerivedN5 extends BaseN5;
  function :initial void f3(); endfunction
endclass
module p08_20_spec_n5;
endmodule
