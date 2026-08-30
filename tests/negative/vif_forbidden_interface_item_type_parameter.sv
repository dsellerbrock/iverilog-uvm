// NEG-DIAG: shall not be declared as an interface item
// NEG-DIAG-COUNT: 5
// IEEE 1800-2017/2023 25.9: the interface-item prohibition survives
// concrete type-parameter defaults and actuals.
interface vif_forbidden_item_type_parameter_negative_target_if;
  logic signal;
endinterface

typedef virtual interface vif_forbidden_item_type_parameter_negative_target_if
    vif_forbidden_item_type_parameter_negative_t;

virtual interface vif_forbidden_item_type_parameter_negative_target_if
    vif_forbidden_item_type_parameter_negative_prototype_vif;
typedef type(vif_forbidden_item_type_parameter_negative_prototype_vif)
    vif_forbidden_item_type_parameter_negative_expression_t;

package vif_forbidden_item_type_parameter_negative_pkg;
  typedef virtual interface vif_forbidden_item_type_parameter_negative_target_if
      vif_t;
endpackage

typedef vif_forbidden_item_type_parameter_negative_forward_t;

interface vif_forbidden_item_type_parameter_negative_forward_if;
  vif_forbidden_item_type_parameter_negative_forward_t forward_completed_vif;
endinterface

typedef virtual interface vif_forbidden_item_type_parameter_negative_target_if
    vif_forbidden_item_type_parameter_negative_forward_t;

interface vif_forbidden_item_type_parameter_negative_default_if #(
    parameter type T =
        virtual interface vif_forbidden_item_type_parameter_negative_target_if
);
  T default_vif;
endinterface

interface vif_forbidden_item_type_parameter_negative_actual_if #(
    parameter type T = int
);
  T actual_vif;
  if (1) begin : generated_items
    T generated_vif;
  end
endinterface

interface vif_forbidden_item_type_parameter_negative_expression_if #(
    parameter type T = int
);
  T type_expression_vif;
endinterface

module vif_forbidden_interface_item_type_parameter;
  vif_forbidden_item_type_parameter_negative_forward_if
      forward_completed_container();
  vif_forbidden_item_type_parameter_negative_default_if default_container();
  vif_forbidden_item_type_parameter_negative_actual_if #(
      .T(vif_forbidden_item_type_parameter_negative_pkg::vif_t)
  ) actual_container();
  vif_forbidden_item_type_parameter_negative_expression_if #(
      .T(vif_forbidden_item_type_parameter_negative_expression_t)
  ) type_expression_container();
endmodule
