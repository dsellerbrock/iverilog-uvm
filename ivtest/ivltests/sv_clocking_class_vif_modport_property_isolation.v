// Distinct modport-qualified VIF typedefs stored in inherited class properties
// must retain independent access restrictions even when they name one interface
// instance.
`timescale 1ns/1ps

interface class_mp_property_isolation_if(input logic clk);
  logic driven;
  logic observed;

  clocking driver_cb @(posedge clk);
    output driven;
  endclocking

  clocking monitor_cb @(posedge clk);
    input observed;
  endclocking

  modport driver_mp(clocking driver_cb);
  modport monitor_mp(clocking monitor_cb);
endinterface

typedef virtual class_mp_property_isolation_if.driver_mp class_driver_vif_t;
typedef virtual class_mp_property_isolation_if.monitor_mp class_monitor_vif_t;

class class_mp_property_base;
  class_driver_vif_t driver_vif;
endclass

class class_mp_property_derived extends class_mp_property_base;
  class_monitor_vif_t monitor_vif;
endclass

module sv_clocking_class_vif_modport_property_isolation;
  logic clk = 1'b0;
  class_mp_property_isolation_if bus(clk);
  class_mp_property_derived holder;
  int failures = 0;

  always #5 clk = ~clk;

  initial begin
    holder = new;
    holder.driver_vif = bus;
    holder.monitor_vif = bus;
    bus.driven = 1'b0;
    bus.observed = 1'b1;

    #1 holder.driver_vif.driver_cb.driven <= 1'b1;
    @(holder.monitor_vif.monitor_cb);
    #1;
    if (bus.driven !== 1'b1) begin
      failures++;
      $display("FAILED inherited driver property: driven=%b", bus.driven);
    end
    if (holder.monitor_vif.monitor_cb.observed !== 1'b1) begin
      failures++;
      $display("FAILED derived monitor property: observed=%b",
               holder.monitor_vif.monitor_cb.observed);
    end

    if (failures != 0)
      $fatal(1, "%0d property-isolation checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule
