// IEEE 1800-2017/2023 25.9: virtual interfaces shall not be used as union
// members.  Unpacked struct members are legal and covered by the positive
// context test; unpacked unions below pin direct, typedef, and concrete
// type-parameter default/actual carriers.
interface sv_vif_forbidden_union_if;
  logic signal;
endinterface

typedef virtual interface sv_vif_forbidden_union_if
    sv_vif_forbidden_union_t;

virtual interface sv_vif_forbidden_union_if
    sv_vif_forbidden_union_prototype_vif;
typedef type(sv_vif_forbidden_union_prototype_vif)
    sv_vif_forbidden_union_type_expression_t;

// `type(prototype)' uses lexical lookup, never the parent instance's scope.
// These compilation-unit declarations are deliberately shadowed in opposite
// directions by the two parent modules below.
virtual interface sv_vif_forbidden_union_if
    sv_vif_forbidden_union_lexical_vif;
int sv_vif_forbidden_union_lexical_int;

package sv_vif_forbidden_union_pkg;
  typedef virtual interface sv_vif_forbidden_union_if vif_t;
endpackage

typedef union {
  virtual interface sv_vif_forbidden_union_if direct_vif;
  int control;
} sv_vif_forbidden_direct_union_t;

typedef union {
  sv_vif_forbidden_union_t typedef_vif;
  int control;
} sv_vif_forbidden_typedef_union_t;

typedef union {
  sv_vif_forbidden_union_type_expression_t type_expression_vif;
  int control;
} sv_vif_forbidden_type_expression_union_t;

module sv_vif_forbidden_union_type_default #(
    parameter type T = virtual interface sv_vif_forbidden_union_if
);
  typedef union {
    T default_vif;
    int control;
  } local_union_t;
  local_union_t value;
endmodule

module sv_vif_forbidden_union_type_actual #(
    parameter type T = int
);
  typedef union {
    T actual_vif;
    int control;
  } local_union_t;
  local_union_t value;
endmodule

module sv_vif_forbidden_union_shadow_reject_child;
  typedef type(sv_vif_forbidden_union_lexical_vif) lexical_t;
  typedef union {
    lexical_t vif;
    int control;
  } local_union_t;
  local_union_t value;
endmodule

module sv_vif_forbidden_union_shadow_reject_parent;
  int sv_vif_forbidden_union_lexical_vif;
  sv_vif_forbidden_union_shadow_reject_child child();
endmodule

module sv_vif_forbidden_union_shadow_legal_child;
  typedef type(sv_vif_forbidden_union_lexical_int) lexical_t;
  typedef union {
    lexical_t value;
    int control;
  } local_union_t;
  local_union_t value;
endmodule

module sv_vif_forbidden_union_shadow_legal_parent;
  virtual interface sv_vif_forbidden_union_if
      sv_vif_forbidden_union_lexical_int;
  sv_vif_forbidden_union_shadow_legal_child child();
endmodule

module sv_vif_forbidden_union_member_fail;
  sv_vif_forbidden_direct_union_t direct_union;
  sv_vif_forbidden_typedef_union_t typedef_union;
  sv_vif_forbidden_type_expression_union_t type_expression_union;
  sv_vif_forbidden_union_type_default default_instance();
  sv_vif_forbidden_union_type_actual #(
      .T(sv_vif_forbidden_union_pkg::vif_t)
  ) actual_instance();
  sv_vif_forbidden_union_shadow_reject_parent shadow_reject_instance();
  sv_vif_forbidden_union_shadow_legal_parent shadow_legal_instance();
endmodule
