// NEG-DIAG: shall not be used as a union member
// NEG-DIAG-COUNT: 6
// IEEE 1800-2017/2023 25.9: virtual interfaces shall not be union members;
// the restriction survives typedef and type-parameter carriers.
interface vif_forbidden_union_negative_if;
  logic signal;
endinterface

typedef virtual interface vif_forbidden_union_negative_if
    vif_forbidden_union_negative_t;

virtual interface vif_forbidden_union_negative_if
    vif_forbidden_union_negative_prototype_vif;
typedef type(vif_forbidden_union_negative_prototype_vif)
    vif_forbidden_union_negative_type_expression_t;

virtual interface vif_forbidden_union_negative_if
    vif_forbidden_union_negative_lexical_vif;
int vif_forbidden_union_negative_lexical_int;

package vif_forbidden_union_negative_pkg;
  typedef virtual interface vif_forbidden_union_negative_if vif_t;
endpackage

typedef union {
  virtual interface vif_forbidden_union_negative_if direct_vif;
  int control;
} vif_forbidden_union_negative_direct_t;

typedef union {
  vif_forbidden_union_negative_t typedef_vif;
  int control;
} vif_forbidden_union_negative_typedef_t;

typedef union {
  vif_forbidden_union_negative_type_expression_t type_expression_vif;
  int control;
} vif_forbidden_union_negative_type_expression_container_t;

module vif_forbidden_union_negative_type_default #(
    parameter type T = virtual interface vif_forbidden_union_negative_if
);
  typedef union {
    T default_vif;
    int control;
  } local_union_t;
  local_union_t value;
endmodule

module vif_forbidden_union_negative_type_actual #(
    parameter type T = int
);
  typedef union {
    T actual_vif;
    int control;
  } local_union_t;
  local_union_t value;
endmodule

module vif_forbidden_union_negative_shadow_reject_child;
  typedef type(vif_forbidden_union_negative_lexical_vif) lexical_t;
  typedef union {
    lexical_t vif;
    int control;
  } local_union_t;
  local_union_t value;
endmodule

module vif_forbidden_union_negative_shadow_reject_parent;
  int vif_forbidden_union_negative_lexical_vif;
  vif_forbidden_union_negative_shadow_reject_child child();
endmodule

module vif_forbidden_union_negative_shadow_legal_child;
  typedef type(vif_forbidden_union_negative_lexical_int) lexical_t;
  typedef union {
    lexical_t value;
    int control;
  } local_union_t;
  local_union_t value;
endmodule

module vif_forbidden_union_negative_shadow_legal_parent;
  virtual interface vif_forbidden_union_negative_if
      vif_forbidden_union_negative_lexical_int;
  vif_forbidden_union_negative_shadow_legal_child child();
endmodule

module vif_forbidden_union_member_direct_typedef;
  vif_forbidden_union_negative_direct_t direct_union;
  vif_forbidden_union_negative_typedef_t typedef_union;
  vif_forbidden_union_negative_type_expression_container_t
      type_expression_union;
  vif_forbidden_union_negative_type_default default_instance();
  vif_forbidden_union_negative_type_actual #(
      .T(vif_forbidden_union_negative_pkg::vif_t)
  ) actual_instance();
  vif_forbidden_union_negative_shadow_reject_parent shadow_reject_instance();
  vif_forbidden_union_negative_shadow_legal_parent shadow_legal_instance();
endmodule
