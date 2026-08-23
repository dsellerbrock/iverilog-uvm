// Separate module ports can alias the same concrete interface variable. Each
// continuous assignment is one driver, so the late binding pass must reject
// the second driver on the shared member.
interface variable_driver_if;
  logic value;
endinterface

module first_variable_driver(variable_driver_if bus, input logic source);
  assign bus.value = source;
endmodule

module second_variable_driver(variable_driver_if bus, input logic source);
  assign bus.value = source;
endmodule

module sv_interface_member_variable_contassign_multidriver_fail;
  variable_driver_if bus();
  logic first_source;
  logic second_source;

  first_variable_driver first_driver(.bus(bus), .source(first_source));
  second_variable_driver second_driver(.bus(bus), .source(second_source));
endmodule
