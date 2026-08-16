module main;
  class state_t;
    bit value;
  endclass

  state_t state;
  logic y;

  // Class-property hardware lowering is not implemented. Synthesis must fail
  // with a diagnostic instead of asserting when expression lowering returns
  // no structural signal.
  always_comb y = state.value;
endmodule
