// IEEE 1800-2017 8.24: an out-of-block method body must be declared in
// the same scope as its class. A unit class must not be rebound from a module,
// and the diagnostic must not leave the parser outside the module scope.
class unit_c;
  extern function int read();
endclass

module test;
  function int unit_c::read();
    return 1;
  endfunction
endmodule
