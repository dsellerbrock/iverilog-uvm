class StaticConstructor;
  static function new();
  endfunction
endclass

class VirtualConstructor;
  virtual function new();
  endfunction
endclass

class ExternStaticConstructor;
  extern static function new();
endclass

function ExternStaticConstructor::new();
endfunction

class ExternVirtualConstructor;
  extern virtual function new();
endclass

function ExternVirtualConstructor::new();
endfunction

module test;
endmodule
