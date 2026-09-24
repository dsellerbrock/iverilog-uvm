`timescale 1ns/1ps

interface disjoint_if;
  logic count;
  logic reset;
endinterface

module disjoint_producer(output logic count);
  assign count = 1'b0;
endmodule

module disjoint_port_legal;
  disjoint_if bus();
  disjoint_producer dut(bus.count);
  virtual disjoint_if vif;
  initial begin
    vif = bus;
    vif.reset = 1'b1;
    #1;
    if (bus.count !== 1'b0 || bus.reset !== 1'b1)
      $fatal(1, "different-member port drive failed");
    $display("PASSED");
  end
endmodule

module disjoint_direct_legal;
  disjoint_if bus();
  assign bus.count = 1'b0;
  virtual disjoint_if vif;
  initial begin
    vif = bus;
    vif.reset = 1'b1;
    #1;
    if (bus.count !== 1'b0 || bus.reset !== 1'b1)
      $fatal(1, "different-member direct drive failed");
    $display("PASSED");
  end
endmodule

module disjoint_port_same_member_illegal;
  disjoint_if bus();
  disjoint_producer dut(bus.count);
  virtual disjoint_if vif;
  initial begin
    vif = bus;
    vif.count = 1'b1;
  end
endmodule

module disjoint_port_uncertain_receiver_illegal;
  disjoint_if driven(), other();
  disjoint_producer dut(driven.count);
  virtual disjoint_if vif;
  initial begin
    if ($test$plusargs("OTHER")) vif = other;
    else vif = driven;
    vif.count = 1'b1;
  end
endmodule

interface disjoint_alias_if;
  logic count;
  logic reset;
  modport drive(output .reset(count));
endinterface

module disjoint_port_modport_alias_illegal;
  disjoint_alias_if bus();
  disjoint_producer dut(bus.count);
  virtual disjoint_alias_if.drive vif;
  initial begin
    vif = bus;
    vif.reset = 1'b1;
  end
endmodule

module disjoint_direct_same_member_illegal;
  disjoint_if bus();
  assign bus.count = 1'b0;
  virtual disjoint_if vif;
  initial begin
    vif = bus;
    vif.count = 1'b1;
  end
endmodule
