// IEEE 1800-2017/2023 25.9: a forward-spelled explicit virtual-interface
// class property is legal syntax, but its interface type must resolve during
// elaboration.
class sv_vif_explicit_class_missing_holder;
  virtual interface sv_vif_explicit_class_missing_if vif;
endclass

module sv_vif_explicit_interface_class_missing_fail;
  sv_vif_explicit_class_missing_holder holder;

  initial holder = new;
endmodule
