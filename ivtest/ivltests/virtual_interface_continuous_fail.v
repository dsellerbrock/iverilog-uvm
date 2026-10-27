interface virtual_interface_continuous_if;
  logic a;
endinterface

module virtual_interface_continuous_fail;
  virtual interface virtual_interface_continuous_if vif = actual;
  virtual_interface_continuous_if actual();
  wire w;

  assign w = vif.a;
endmodule
