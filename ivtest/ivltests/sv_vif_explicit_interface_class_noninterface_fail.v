// IEEE 1800-2017/2023 25.9: a resolved type following
// `virtual interface' must denote an interface, not a class.
class sv_vif_explicit_class_not_an_interface;
endclass

class sv_vif_explicit_class_noninterface_holder;
  virtual interface sv_vif_explicit_class_not_an_interface vif;
endclass

module sv_vif_explicit_interface_class_noninterface_fail;
  sv_vif_explicit_class_noninterface_holder holder;
endmodule
