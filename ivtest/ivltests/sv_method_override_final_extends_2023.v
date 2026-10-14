class method_override_base;
  virtual function int value();
    return 1;
  endfunction
endclass

class method_override_middle extends method_override_base;
  function :final :extends int value();
    return 2;
  endfunction
endclass

class method_override_derived extends method_override_middle;
  function int value();
    return 3;
  endfunction
endclass

module test;
  method_override_derived value;
endmodule
