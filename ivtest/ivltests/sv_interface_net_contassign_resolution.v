`timescale 1ns/1ps

// Interface net members retain ordinary continuous-driver semantics even
// though the enclosing interface port is represented by a runtime handle.
// Each source-level assignment needs its own structural driver so default and
// explicit strengths resolve, and net delay remains inertial.
interface resolved_member_if;
  wire resolved;
  wire strength_resolved;
  wire delayed;
endinterface

module resolved_member_drivers(
  resolved_member_if bus,
  input logic x,
  input logic y,
  input logic weak_value,
  input logic strong_value,
  input logic delayed_value
);
  assign bus.resolved = x;
  assign bus.resolved = y;
  assign (weak1, weak0) bus.strength_resolved = weak_value;
  assign (strong1, strong0) bus.strength_resolved = strong_value;
  assign #2 bus.delayed = delayed_value;
endmodule

module sv_interface_net_contassign_resolution;
  resolved_member_if bus();
  logic x;
  logic y;
  logic weak_value;
  logic strong_value;
  logic delayed_value;

  resolved_member_drivers dut(
    .bus(bus),
    .x(x),
    .y(y),
    .weak_value(weak_value),
    .strong_value(strong_value),
    .delayed_value(delayed_value)
  );

  task automatic check(input logic got, input logic expected,
                       input string where);
    if (got !== expected) begin
      $display("FAILED %s t=%0t got=%b expected=%b",
               where, $time, got, expected);
      $fatal(1);
    end
  endtask

  initial begin
    x = 1'b0;
    y = 1'bz;
    weak_value = 1'b1;
    strong_value = 1'bz;
    delayed_value = 1'b0;
    #0.1;
    check(bus.resolved, 1'b0, "one active default driver");
    check(bus.strength_resolved, 1'b1, "weak driver");

    y = 1'b1;
    strong_value = 1'b0;
    #0.1;
    check(bus.resolved, 1'bx, "conflicting default drivers");
    check(bus.strength_resolved, 1'b0, "strong overrides weak");

    x = 1'bz;
    #0.1;
    check(bus.resolved, 1'b1, "other default driver remains");

    #0.7;
    check(bus.delayed, 1'bx, "initial delayed drive pending");
    #1.1;
    check(bus.delayed, 1'b0, "initial delayed drive delivered");
    delayed_value = 1'b1;
    #1;
    check(bus.delayed, 1'b0, "rise delay pending");
    #1.1;
    check(bus.delayed, 1'b1, "rise delay delivered");

    $display("PASSED");
  end
endmodule
