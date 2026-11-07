// IEEE 1800-2017/2023 25.9: "it shall be illegal to use an interface
// containing those references [hierarchical references to objects outside
// its body, or ports that reference other interfaces] in the declaration
// of a virtual interface."
interface issue921_read_if;
  logic x;
  assign x = issue921_top.g;
endinterface

interface issue921_write_if;
  logic x = 1'b0;
  assign issue921_top.w = x;
endinterface

interface issue921_nested_if;
  logic y;
endinterface

interface issue921_port_if(issue921_nested_if nested);
endinterface

// A hierarchical reference that stays inside the interface is legal.
interface issue921_clean_if;
  issue921_nested_if inner();
  logic z;
  assign z = inner.y;
endinterface

module issue921_top;
  logic g = 1'b1;
  wire w;
  issue921_read_if read_bus();
  issue921_write_if write_bus();
  issue921_nested_if nested_bus();
  issue921_port_if port_bus(nested_bus);
  issue921_clean_if clean_bus();
  virtual issue921_read_if read_vif;
  virtual issue921_write_if write_vif;
  virtual issue921_port_if port_vif;
  virtual issue921_clean_if clean_vif;
endmodule
