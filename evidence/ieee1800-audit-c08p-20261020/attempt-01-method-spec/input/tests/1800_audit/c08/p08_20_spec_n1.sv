// IEEE 1800-2023 §8.20 Example 3: :extends without a virtual base method.
class BaseN1;
  function void f1(); endfunction
endclass
class DerivedN1 extends BaseN1;
  function :extends void f5(); endfunction
endclass
module p08_20_spec_n1;
endmodule
