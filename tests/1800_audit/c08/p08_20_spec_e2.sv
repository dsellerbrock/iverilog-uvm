// IEEE 1800-2023 §8.20: :final is illegal on a pure-virtual method.
virtual class E2;
  pure virtual function :final void p();
endclass
module p08_20_spec_e2;
endmodule
