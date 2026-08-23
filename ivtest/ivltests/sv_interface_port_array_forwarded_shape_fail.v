interface forwarded_shape_if;
  logic value;
  modport access(input value);
endinterface

module forwarded_shape_leaf(forwarded_shape_if.access ports [0:0][0:1]);
endmodule

module forwarded_shape_middle(forwarded_shape_if.access ports [1:0]);
  forwarded_shape_leaf leaf(.ports(ports));
endmodule

module sv_interface_port_array_forwarded_shape_fail;
  forwarded_shape_if bus [3:2] ();
  forwarded_shape_middle middle(.ports(bus));
endmodule
