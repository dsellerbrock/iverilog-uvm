// M12-6: modport direction/access metadata through VPI — each
// modport of an interface exposes its port list via
// vpi_iterate(vpiIODecl) with per-port vpiDirection.
interface bus_if;
  logic        clk;
  logic [7:0]  wdata;
  logic [7:0]  rdata;
  logic        valid;
  logic        ready;
  modport mst (output wdata, output valid, input rdata, input ready,
               input clk);
  modport slv (input wdata, input valid, output rdata, output ready,
               input clk);
  modport mon (input clk, input wdata, input rdata, input valid,
               input ready);
endinterface

module top;
  bus_if bus();
  initial begin
    $m12mp_probe;
    $finish(0);
  end
endmodule
