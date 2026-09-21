interface real_if;
  real sample;
endinterface

class real_cfg;
  virtual real_if vif;
endclass

module test;
  real_if bus();
  real_cfg cfg;
  initial begin
    cfg = new;
    cfg.vif = bus;
    @(posedge cfg.vif.sample);
  end
endmodule
