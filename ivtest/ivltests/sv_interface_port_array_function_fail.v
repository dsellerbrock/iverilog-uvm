interface port_array_function_if;
  int value;

  function automatic int read_value();
    return value;
  endfunction

  modport access(input value, import read_value);
endinterface

module port_array_function_consumer(
  port_array_function_if.access ports [0:1],
  output int value
);
  always_comb begin
    value = ports[1].read_value();
  end
endmodule

module sv_interface_port_array_function_fail;
  int value;
  port_array_function_if bus [0:1] ();
  port_array_function_consumer consumer(.ports(bus), .value(value));
endmodule
