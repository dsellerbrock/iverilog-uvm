module ref_port_child(ref int x);
endmodule

module sv_module_ref_port_net_fail;
  wire [31:0] value;
  ref_port_child child(value);
endmodule
