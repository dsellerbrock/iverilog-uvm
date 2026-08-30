// IEEE 1800-2017/2023 25.9: a virtual-interface type carried through a
// concrete type-parameter default or actual remains forbidden as an
// interface item.  This is separate from the direct/typedef CE row because
// its parse-form errors would otherwise stop before these cases elaborate.
interface sv_vif_forbidden_item_type_parameter_target_if;
  logic signal;
endinterface

typedef virtual interface sv_vif_forbidden_item_type_parameter_target_if
    sv_vif_forbidden_item_type_parameter_t;

virtual interface sv_vif_forbidden_item_type_parameter_target_if
    sv_vif_forbidden_item_type_parameter_prototype_vif;
typedef type(sv_vif_forbidden_item_type_parameter_prototype_vif)
    sv_vif_forbidden_item_type_expression_t;

package sv_vif_forbidden_item_type_parameter_pkg;
  typedef virtual interface sv_vif_forbidden_item_type_parameter_target_if
      vif_t;
endpackage

typedef sv_vif_forbidden_item_forward_completed_t;

interface sv_vif_forbidden_item_forward_completed_if;
  sv_vif_forbidden_item_forward_completed_t forward_completed_vif;
endinterface

typedef virtual interface sv_vif_forbidden_item_type_parameter_target_if
    sv_vif_forbidden_item_forward_completed_t;

interface sv_vif_forbidden_item_type_default_if #(
    parameter type T =
        virtual interface sv_vif_forbidden_item_type_parameter_target_if
);
  T default_vif;
endinterface

interface sv_vif_forbidden_item_type_actual_if #(
    parameter type T = int
);
  T actual_vif;
  if (1) begin : generated_items
    T generated_vif;
  end
endinterface

interface sv_vif_forbidden_item_type_expression_if #(
    parameter type T = int
);
  T type_expression_vif;
endinterface

module sv_vif_forbidden_interface_item_type_parameter_fail;
  sv_vif_forbidden_item_forward_completed_if forward_completed_container();
  sv_vif_forbidden_item_type_default_if default_container();
  sv_vif_forbidden_item_type_actual_if #(
      .T(sv_vif_forbidden_item_type_parameter_pkg::vif_t)
  ) actual_container();
  sv_vif_forbidden_item_type_expression_if #(
      .T(sv_vif_forbidden_item_type_expression_t)
  ) type_expression_container();
endmodule
