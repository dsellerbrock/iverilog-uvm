// NEG-DIAG: shall not be used as a module, interface, or program port
// NEG-DIAG-COUNT: 7
// IEEE 1800-2017/2023 25.9: virtual interfaces shall not be used as ports;
// the restriction survives typedef and type-parameter carriers.  The
// ordinary interface port is a legal provenance control.
interface vif_forbidden_port_negative_if;
  logic signal;
endinterface

typedef virtual interface vif_forbidden_port_negative_if
    vif_forbidden_port_negative_t;

virtual interface vif_forbidden_port_negative_if
    vif_forbidden_port_negative_prototype_vif;
typedef type(vif_forbidden_port_negative_prototype_vif)
    vif_forbidden_port_negative_type_expression_t;

module vif_forbidden_port_negative_direct(
    input virtual interface vif_forbidden_port_negative_if vif);
endmodule

module vif_forbidden_port_negative_typedef(
    input vif_forbidden_port_negative_t vif);
endmodule

module vif_forbidden_port_negative_type_expression(
    input vif_forbidden_port_negative_type_expression_t vif);
endmodule

interface vif_forbidden_port_negative_interface_port(
    input virtual interface vif_forbidden_port_negative_if vif);
endinterface

program vif_forbidden_port_negative_program_port(
    input virtual interface vif_forbidden_port_negative_if vif);
endprogram

module vif_forbidden_port_negative_type_default #(
    parameter type T = virtual interface vif_forbidden_port_negative_if
) (input T vif);
endmodule

module vif_forbidden_port_negative_type_actual #(
    parameter type T = int
) (input T vif);
endmodule

module vif_forbidden_port_negative_ordinary_control(
    vif_forbidden_port_negative_if vif);
endmodule

module vif_forbidden_port_direct_typedef;
  vif_forbidden_port_negative_if bus();
  vif_forbidden_port_negative_direct direct_instance(bus);
  vif_forbidden_port_negative_typedef typedef_instance(bus);
  vif_forbidden_port_negative_type_expression type_expression_instance(bus);
  vif_forbidden_port_negative_interface_port interface_instance(bus);
  vif_forbidden_port_negative_program_port program_instance(bus);
  vif_forbidden_port_negative_type_default default_instance(bus);
  vif_forbidden_port_negative_type_actual #(
      .T(vif_forbidden_port_negative_t)
  ) actual_instance(bus);
  vif_forbidden_port_negative_ordinary_control legal_control(bus);
endmodule
