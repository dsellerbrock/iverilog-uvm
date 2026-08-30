// A resolved TYPE_IDENTIFIER after `virtual interface` still has to denote an
// interface type (IEEE 1800-2017/2023 25.9).
class vif_explicit_interface_not_an_interface;
endclass

class vif_explicit_interface_noninterface_holder;
  virtual interface vif_explicit_interface_not_an_interface vif;
endclass

module virtual_interface_explicit_class_known_noninterface;
  vif_explicit_interface_noninterface_holder object;
endmodule
