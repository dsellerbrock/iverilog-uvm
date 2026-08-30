// IEEE 1800-2017/2023 25.9: virtual interfaces shall not be used as
// module, interface, or program ports.  Pin direct, typedef-carried, and
// type-parameter-default/actual virtual-interface types independently.
// An ordinary interface port is the legal control: it reaches the same
// eventual interface netclass but has no virtual-interface provenance.
interface sv_vif_forbidden_port_if;
  logic signal;
endinterface

typedef virtual interface sv_vif_forbidden_port_if
    sv_vif_forbidden_port_t;

virtual interface sv_vif_forbidden_port_if
    sv_vif_forbidden_port_prototype_vif;
typedef type(sv_vif_forbidden_port_prototype_vif)
    sv_vif_forbidden_port_type_expression_t;

module sv_vif_forbidden_port_direct(
    input virtual interface sv_vif_forbidden_port_if vif);
endmodule

module sv_vif_forbidden_port_typedef(
    input sv_vif_forbidden_port_t vif);
endmodule

module sv_vif_forbidden_port_type_expression(
    input sv_vif_forbidden_port_type_expression_t vif);
endmodule

interface sv_vif_forbidden_interface_port(
    input virtual interface sv_vif_forbidden_port_if vif);
endinterface

program sv_vif_forbidden_program_port(
    input virtual interface sv_vif_forbidden_port_if vif);
endprogram

module sv_vif_forbidden_port_type_default #(
    parameter type T = virtual interface sv_vif_forbidden_port_if
) (input T vif);
endmodule

module sv_vif_forbidden_port_type_actual #(
    parameter type T = int
) (input T vif);
endmodule

module sv_vif_ordinary_interface_port_control(
    sv_vif_forbidden_port_if vif);
endmodule

module sv_vif_forbidden_port_fail;
  sv_vif_forbidden_port_if bus();
  sv_vif_forbidden_port_direct direct_instance(bus);
  sv_vif_forbidden_port_typedef typedef_instance(bus);
  sv_vif_forbidden_port_type_expression type_expression_instance(bus);
  sv_vif_forbidden_interface_port interface_instance(bus);
  sv_vif_forbidden_program_port program_instance(bus);
  sv_vif_forbidden_port_type_default default_instance(bus);
  sv_vif_forbidden_port_type_actual #(
      .T(sv_vif_forbidden_port_t)
  ) actual_instance(bus);
  sv_vif_ordinary_interface_port_control legal_control(bus);
endmodule
