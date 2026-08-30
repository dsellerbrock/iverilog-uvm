// NEG-DIAG: error: virtual may only be used with interface types.
// NEG-DIAG-COUNT: 1
// IEEE 1800-2017/2023 25.9: a class is not a legal virtual-interface type.
class vif_explicit_negative_not_an_interface;
endclass

class vif_explicit_negative_noninterface_holder;
  virtual interface vif_explicit_negative_not_an_interface vif;
endclass

module vif_explicit_interface_class_noninterface;
  vif_explicit_negative_noninterface_holder holder;
endmodule
