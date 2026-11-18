interface used_if(input logic clk);
  modport outside_clock(clocking cbx);
endinterface

interface unused_if;
  logic signal_only;
  modport invalid_clocks(clocking missing, clocking signal_only);
endinterface

interface outer_if(input logic clk);
  clocking outer_cb @(posedge clk);
  endclocking
  interface nested_if;
    modport nested_view(clocking outer_cb);
  endinterface
endinterface

interface generate_if(input logic clk);
  if (1) begin : g
    clocking generated_cb @(posedge clk);
    endclocking
  end
  modport generate_view(clocking generated_cb);
endinterface

interface anonymous_if(input logic clk);
  default clocking @(posedge clk);
  endclocking
  // Escaping an internal storage name cannot give this block a source name.
  modport anonymous_view(clocking \$default_clocking );
endinterface

module sv_modport_clocking_scope_fail;
  logic clk = 0;
  clocking cbx @(posedge clk);
  endclocking
  used_if bus(clk);
  generate_if generated_bus(clk);
endmodule
