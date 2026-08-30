// IEEE 1800-2017/2023 25.5 and 25.9: an explicit-keyword virtual
// interface class property must retain its modport view. A member omitted
// from that modport is not visible through the property.
interface sv_vif_explicit_class_modport_if;
  logic visible;
  logic hidden;
  modport observe(input visible);
endinterface

class sv_vif_explicit_class_modport_holder;
  virtual interface sv_vif_explicit_class_modport_if.observe vif;
endclass

module sv_vif_explicit_interface_class_modport_fail;
  sv_vif_explicit_class_modport_if bus();
  sv_vif_explicit_class_modport_holder holder;
  logic observed;

  initial begin
    holder = new;
    holder.vif = bus;
    observed = holder.vif.hidden;
  end
endmodule
