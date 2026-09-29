interface pins_if #(parameter int Width = 1, parameter string PullStrength = "None");
  logic [Width-1:0] pins_pd;
endinterface

interface chip_if;
  pins_if #(.Width(5), .PullStrength("Weak")) mios_if();
endinterface

class cfg;
  virtual chip_if chip_vif;
  virtual pins_if #(.Width(5), .PullStrength("Weak")) mios_vif;
  function void bind_children();
    mios_vif = chip_vif.mios_if;
  endfunction
endclass

module top;
  chip_if actual();
  cfg c;
  initial begin
    c = new;
    c.chip_vif = actual;
    c.bind_children();
    c.mios_vif.pins_pd = '1;
    if (actual.mios_if.pins_pd !== '1) $fatal(1, "alias failed");
    $display("PASS parameterized nested VIF alias");
  end
endmodule
