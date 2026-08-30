// NEG-DIAG: error: Unknown interface type `vif_explicit_negative_missing_if'.
// NEG-DIAG-COUNT: 1
// IEEE 1800-2017/2023 25.9: a forward-spelled virtual-interface type must
// resolve during elaboration.
class vif_explicit_negative_missing_holder;
  virtual interface vif_explicit_negative_missing_if vif;
endclass

module vif_explicit_interface_class_missing;
  vif_explicit_negative_missing_holder holder;
  initial holder = new;
endmodule
