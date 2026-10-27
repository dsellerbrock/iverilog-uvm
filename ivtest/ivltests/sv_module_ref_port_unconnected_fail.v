module ref_port_child(ref int x);
endmodule

module sv_module_ref_port_unconnected_fail;
  ref_port_child child();
endmodule
