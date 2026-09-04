// IEEE 1800-2017/2023 8.21 -- an abstract (virtual) class shall never be
// instantiated. No type parameter is involved here, so nothing can have
// collapsed to a virtual base: this is a plain error.
//
// Icarus previously degraded this to null with only a warning, because the
// compile-progress gate was "anywhere inside any class scope". Illegal source
// therefore compiled and ran with a null handle. slang 11.0.448 rejects it.
// The gate is now the 8.25 template seed only; this test pins the difference.
virtual class base;
endclass

class holder;
  base b;
  function void mk();
    b = new();
  endfunction
endclass

module main;
  holder h = new();
  initial h.mk();
endmodule
