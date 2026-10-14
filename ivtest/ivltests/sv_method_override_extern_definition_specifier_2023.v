class method_override_extern_base;
  virtual function int value();
    return 1;
  endfunction
endclass

class method_override_extern_derived extends method_override_extern_base;
  extern function :extends int value();
endclass

function :extends int method_override_extern_derived::value();
  return 2;
endfunction

module test;
endmodule
