// IEEE 1800-2023 §8.20: overriding :final is illegal even when non-virtual.
class BaseE3;
  function :final void h(); endfunction
endclass
class DerivedE3 extends BaseE3;
  function void h(); endfunction
endclass
module p08_20_spec_e3;
endmodule
