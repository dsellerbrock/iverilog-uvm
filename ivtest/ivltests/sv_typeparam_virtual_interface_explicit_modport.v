interface vif_default_modport_known_if;
  logic signal;
  modport observe(input signal);
endinterface

class vif_default_modport_known_holder #(
  type IFType = virtual interface vif_default_modport_known_if.observe
);
  IFType value;
endclass

class vif_default_modport_forward_holder #(
  type IFType = virtual interface vif_default_modport_forward_if.observe
);
  IFType value;
endclass

interface vif_default_modport_forward_if;
  logic signal;
  modport observe(input signal);
endinterface

module sv_typeparam_virtual_interface_explicit_modport;
  vif_default_modport_known_holder known_object;
  vif_default_modport_forward_holder forward_object;

  initial $display("PASSED");
endmodule
