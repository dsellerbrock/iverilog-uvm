interface port_mixed_driver_if;
  logic value;
  task drive(); value = 1'b1; endtask
  modport output_view(output value);
endinterface

module port_mixed_continuous(port_mixed_driver_if p);
  bit source;
  assign p.value = source;
endmodule

module port_mixed_procedural(port_mixed_driver_if p);
  initial p.value = 1'b1;
endmodule

module sv_interface_port_mixed_driver_unused;
  port_mixed_driver_if bus();
  port_mixed_continuous driver(bus);
  initial begin
    #1;
    if (bus.value !== 1'b0) $fatal(1, "port continuous zero failed");
    driver.source = 1'b1;
    #1;
    if (bus.value !== 1'b1) $fatal(1, "port continuous one failed");
    $display("PASSED");
  end
endmodule

module sv_interface_port_mixed_driver_called;
  port_mixed_driver_if bus();
  port_mixed_continuous driver(bus);
  initial bus.drive();
endmodule

module sv_interface_port_mixed_driver_two_port;
  port_mixed_driver_if bus();
  port_mixed_continuous driver(bus);
  port_mixed_procedural writer(bus);
endmodule

module sv_interface_port_mixed_driver_sibling;
  port_mixed_driver_if idle(), used();
  port_mixed_continuous idle_driver(idle);
  port_mixed_continuous used_driver(used);
  initial used.drive();
endmodule

module sv_interface_port_mixed_driver_direct_port;
  port_mixed_driver_if bus();
  port_mixed_procedural writer(bus);
  assign bus.value = 1'b0;
endmodule

module sv_interface_port_mixed_driver_dynamic;
  port_mixed_driver_if bus();
  port_mixed_continuous driver(bus);
  virtual port_mixed_driver_if handle;
  initial begin
    handle = bus;
    handle.value = 1'b1;
  end
endmodule

class port_mixed_holder;
  virtual port_mixed_driver_if handle;
endclass

module sv_interface_port_mixed_driver_class_handle;
  port_mixed_driver_if bus();
  port_mixed_continuous driver(bus);
  port_mixed_holder holder;
  initial begin
    holder = new();
    holder.handle = bus;
    holder.handle.value = 1'b1;
  end
endmodule

module port_mixed_modport_continuous(port_mixed_driver_if.output_view p);
  bit source;
  assign p.value = source;
endmodule

module sv_interface_port_mixed_driver_modport_dynamic;
  port_mixed_driver_if bus();
  port_mixed_modport_continuous driver(bus);
  virtual port_mixed_driver_if handle;
  initial begin
    handle = bus;
    handle.value = 1'b1;
  end
endmodule

interface port_mixed_clean_if;
  logic value;
endinterface

module port_mixed_clean_driver(port_mixed_clean_if p);
  bit source;
  assign p.value = source;
endmodule

module sv_interface_port_mixed_driver_clean;
  port_mixed_clean_if bus();
  port_mixed_clean_driver driver(bus);
  initial begin
    #1;
    if (bus.value !== 1'b0) $fatal(1, "clean forwarded zero failed");
    driver.source = 1'b1;
    #1;
    if (bus.value !== 1'b1) $fatal(1, "clean forwarded one failed");
    $display("PASSED");
  end
endmodule

module port_mixed_ref_writer(port_mixed_driver_if p);
  task automatic write_ref(ref logic target);
    target = 1'b1;
  endtask
  initial write_ref(p.value);
endmodule

module sv_interface_port_mixed_driver_ref_port;
  port_mixed_driver_if bus();
  port_mixed_continuous driver(bus);
  port_mixed_ref_writer writer(bus);
endmodule
