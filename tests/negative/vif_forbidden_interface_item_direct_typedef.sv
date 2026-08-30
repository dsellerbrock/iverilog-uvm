// NEG-DIAG: shall not be declared as an interface item
// NEG-DIAG-COUNT: 2
// IEEE 1800-2017/2023 25.9: virtual interfaces shall not be interface items;
// the restriction survives a typedef carrier.  Concrete type-parameter
// carriers are isolated in a second test so these parse-form errors cannot
// prevent its elaboration.
interface vif_forbidden_item_negative_target_if;
  logic signal;
endinterface

typedef virtual interface vif_forbidden_item_negative_target_if
    vif_forbidden_item_negative_t;

interface vif_forbidden_item_negative_container_if;
  virtual interface vif_forbidden_item_negative_target_if direct_vif;
  vif_forbidden_item_negative_t typedef_vif;
endinterface

module vif_forbidden_interface_item_direct_typedef;
  vif_forbidden_item_negative_container_if container();
endmodule
