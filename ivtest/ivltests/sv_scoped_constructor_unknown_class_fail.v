// A failed scoped-constructor lookup is a source error, not an internal
// assertion. Keep a complete body so cleanup reaches the ordinary end action.
module test;
  function missing_c::new();
  endfunction
endmodule
