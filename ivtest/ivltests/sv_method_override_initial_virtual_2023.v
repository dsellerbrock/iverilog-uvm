class method_override_base;
  virtual function int value();
    return 1;
  endfunction
endclass

class method_override_derived extends method_override_base;
  function :initial int value();
    return 2;
  endfunction
endclass

module test;
  method_override_derived value;
endmodule
