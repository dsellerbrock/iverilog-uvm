// NEG-DIAG: cannot access 'hidden' through modport 'observe'
// NEG-DIAG-COUNT: 1
// IEEE 1800-2017/2023 25.5 and 25.9: an explicit-keyword virtual
// interface class property retains the selected modport view.
interface vif_explicit_negative_modport_if;
  logic visible;
  logic hidden;
  modport observe(input visible);
endinterface

class vif_explicit_negative_modport_holder;
  virtual interface vif_explicit_negative_modport_if.observe vif;
endclass

module vif_explicit_interface_class_modport_unlisted;
  vif_explicit_negative_modport_if bus();
  vif_explicit_negative_modport_holder holder;
  logic observed;

  initial begin
    holder = new;
    holder.vif = bus;
    observed = holder.vif.hidden;
  end
endmodule
