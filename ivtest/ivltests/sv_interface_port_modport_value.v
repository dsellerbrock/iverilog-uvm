// IEEE 1800-2017/2023 25.9: an interface port's modport is a VIF value.
interface port_modport_if(input bit clk);
  logic csb;
  modport tb(input clk, output csb);
  modport dev(input clk, output csb);
endinterface

package port_modport_pkg;
`ifdef BAD_VIEW
  task automatic take(virtual port_modport_if.dev vif);
`else
  task automatic take(virtual port_modport_if.tb vif);
`endif
    vif.csb = 1'b1;
  endtask
endpackage

`ifdef BAD_SOURCE_VIEW
program port_modport_prog(port_modport_if.dev sif);
`else
program port_modport_prog(port_modport_if sif);
`endif
  import port_modport_pkg::*;
  initial begin
`ifndef BAD_SOURCE_VIEW
    take(sif);
`endif
`ifdef BAD_MODPORT_NAME
    take(sif.fake);
`else
    take(sif.tb);
`endif
    #1;
    if (sif.csb !== 1'b1) $fatal(1, "modport task did not drive csb");
    $display("PASSED");
  end
endprogram

module sv_interface_port_modport_value;
  bit clk;
  port_modport_if sif(clk);
  port_modport_prog host(sif);
endmodule
