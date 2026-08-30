// IEEE 1800-2017/2023 25.9 and A.2.2.1: the optional `interface'
// keyword is part of a virtual-interface type. Exercise class properties
// with interfaces known before the class and forward referenced after it,
// with and without a modport, and with multiple property declarators.
interface sv_vif_explicit_known_if;
  logic [7:0] data;
endinterface

interface sv_vif_explicit_parameter_if #(parameter int WIDTH = 8);
  logic [WIDTH-1:0] data;
  modport drive(output data);
endinterface

class sv_vif_explicit_interface_holder;
  virtual interface sv_vif_explicit_known_if known_vif, known_alias_vif;
  virtual interface sv_vif_explicit_parameter_if #(.WIDTH(8)).drive parameter_vif;
  virtual interface sv_vif_explicit_forward_if forward_vif;
  virtual interface sv_vif_explicit_forward_modport_if.drive forward_modport_vif;
endclass

interface sv_vif_explicit_forward_if;
  logic [7:0] data;
endinterface

interface sv_vif_explicit_forward_modport_if;
  logic [7:0] data;
  modport drive(output data);
endinterface

module sv_vif_explicit_interface_class_property;
  sv_vif_explicit_known_if known_bus();
  sv_vif_explicit_parameter_if #(.WIDTH(8)) parameter_bus();
  sv_vif_explicit_forward_if forward_bus();
  sv_vif_explicit_forward_modport_if forward_modport_bus();
  sv_vif_explicit_interface_holder holder;

  initial begin
    holder = new;
    holder.known_vif = known_bus;
    holder.known_alias_vif = known_bus;
    holder.parameter_vif = parameter_bus;
    holder.forward_vif = forward_bus;
    holder.forward_modport_vif = forward_modport_bus;

    holder.known_vif.data = 8'h12;
    if (holder.known_alias_vif.data !== 8'h12)
      $fatal(1, "multiple explicit virtual-interface properties lost identity");

    holder.parameter_vif.data = 8'h34;
    if (parameter_bus.data !== 8'h34)
      $fatal(1, "parameter-spelled explicit virtual-interface property failed");

    holder.forward_vif.data = 8'h56;
    if (forward_bus.data !== 8'h56)
      $fatal(1, "forward explicit virtual-interface property failed");

    holder.forward_modport_vif.data = 8'h78;
    if (forward_modport_bus.data !== 8'h78)
      $fatal(1, "forward modport-qualified explicit virtual-interface property failed");

    $display("PASSED");
  end
endmodule
