interface class I #(int D=3);
  pure virtual function int f(int value=D);
endclass

class Bad implements I#(3);
  virtual function int f(int value=4);
    return value;
  endfunction
endclass

module issue1217_interface_default_value_fail_2017;
endmodule
