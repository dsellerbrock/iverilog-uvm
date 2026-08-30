// IEEE 1800-2017/2023 25.9: virtual interfaces shall not be used as
// interface items.  Pin the direct data_type plus a typedef carrier.  The
// elaboration-time type-parameter carrier cases live in a separate CE row so
// these parse-form diagnostics cannot prevent that elaboration from running.
interface sv_vif_forbidden_item_target_if;
  logic signal;
endinterface

typedef virtual interface sv_vif_forbidden_item_target_if
    sv_vif_forbidden_item_t;

interface sv_vif_forbidden_item_container_if;
  virtual interface sv_vif_forbidden_item_target_if direct_vif;
  sv_vif_forbidden_item_t typedef_vif;
endinterface

module sv_vif_forbidden_interface_item_fail;
  sv_vif_forbidden_item_container_if container();
endmodule
