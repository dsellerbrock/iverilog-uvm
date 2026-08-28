// IEEE 1800-2017/2023 23.11 / Syntax 23-9: when the selected concrete bind
// target is an interface, a module instantiation is illegal. The inactive
// module alternative does not change that selected-occurrence rule.
interface sv_bind_interface_module_intf;
endinterface

module sv_bind_interface_module_leaf;
endmodule

module sv_bind_interface_module_probe;
endmodule

module sv_bind_interface_module_holder #(
  parameter bit USE_INTERFACE = 1'b1
);
  if (USE_INTERFACE) begin : selected
    sv_bind_interface_module_intf child();
  end else begin : selected
    sv_bind_interface_module_leaf child();
  end

  bind selected.child sv_bind_interface_module_probe p();
endmodule

module sv_bind_interface_module_fail;
  sv_bind_interface_module_holder #(.USE_INTERFACE(1'b1)) owner();
endmodule
