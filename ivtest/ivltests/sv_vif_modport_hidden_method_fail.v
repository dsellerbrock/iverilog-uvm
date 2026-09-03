// IEEE 1800-2017/2023 25.7/25.10: a selected virtual interface exposes only
// task/function members imported or exported by that view.
interface hidden_method_if;
  task allowed();
  endtask
  task hidden();
  endtask
  modport restricted(import allowed);
endinterface

module sv_vif_modport_hidden_method_fail;
  hidden_method_if bus();
  virtual hidden_method_if.restricted vif;

  initial begin
    vif = bus.restricted;
    vif.hidden();
  end
endmodule
