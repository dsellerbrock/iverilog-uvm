interface port_array_shape_if;
  logic value;
  modport access(input value);
endinterface

module port_array_shape_consumer(
  port_array_shape_if.access ports [0:1][0:1]
);
endmodule

module sv_interface_port_array_shape_fail;
  port_array_shape_if bus [0:3] ();
  port_array_shape_consumer consumer(.ports(bus));
endmodule
