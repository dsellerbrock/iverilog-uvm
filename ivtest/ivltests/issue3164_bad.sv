// IEEE 1800-2017/2023 25.9: a virtual interface is a procedural handle.
interface issue3164_virtual_bus;
  function int read_n();
    return 3;
  endfunction
  modport h(import read_n);
endinterface

module issue3164_bad;
  issue3164_virtual_bus bus();
  virtual issue3164_virtual_bus.h vif = bus.h;
  int y;
  assign y = vif.read_n();
endmodule
