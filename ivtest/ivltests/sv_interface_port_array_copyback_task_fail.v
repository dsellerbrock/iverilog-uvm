interface port_array_copyback_if;
  int value;

  task automatic read_value(output int result);
    result = value;
  endtask

  modport access(input value, import read_value);
endinterface

module port_array_copyback_consumer(
  port_array_copyback_if.access ports [0:1],
  output int value
);
  initial ports[1].read_value(value);
endmodule

module sv_interface_port_array_copyback_task_fail;
  int value;
  port_array_copyback_if bus [0:1] ();
  port_array_copyback_consumer consumer(.ports(bus), .value(value));
endmodule
