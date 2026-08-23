`timescale 1ns/1ps

// An interface-member r-value still forms an ordinary continuous-assignment
// driver when its destination is an ordinary net. The driver must preserve
// inertial delay, drive strength, multiple-driver resolution, and reactivity.
interface member_net_if;
  logic source;
endinterface

module member_net_bridge(
  member_net_if bus,
  output wire delayed,
  output wire weak_driven,
  output wire concat_hi,
  output wire concat_lo,
  output wire called,
  output wire streamed,
  output wire postselected
);
  function automatic logic invert(input logic value);
    return ~value;
  endfunction

  assign #2 delayed = bus.source;
  assign (weak1, weak0) weak_driven = bus.source;

  // Exercise non-identifier l-values and parse-form wrappers around an
  // interface-member read. Each remains an ordinary structural driver.
  assign {concat_hi, concat_lo} = {bus.source, ~bus.source};
  assign called = invert(bus.source);
  assign streamed = {>>{bus.source}};
  assign postselected = {bus.source, ~bus.source}[1];
endmodule

module sv_interface_member_contassign_net_semantics;
  member_net_if bus();
  wire delayed;
  tri resolved;
  wire concat_hi;
  wire concat_lo;
  wire called;
  wire streamed;
  wire postselected;
  logic strong_enable;

  member_net_bridge dut(.bus(bus), .delayed(delayed),
                         .weak_driven(resolved), .concat_hi(concat_hi),
                         .concat_lo(concat_lo), .called(called),
                         .streamed(streamed), .postselected(postselected));
  assign (strong1, strong0) resolved = strong_enable ? 1'b0 : 1'bz;

  task automatic check(input logic got, input logic expected,
                       input string where);
    if (got !== expected) begin
      $display("FAILED %s t=%0t got=%b expected=%b",
               where, $time, got, expected);
      $fatal(1);
    end
  endtask

  initial begin
    strong_enable = 1'b0;
    bus.source = 1'b0;

    #1;
    check(delayed, 1'bx, "initial delay pending");
    check(resolved, 1'b0, "weak zero");
    check(concat_hi, 1'b0, "concat lvalue high");
    check(concat_lo, 1'b1, "concat lvalue low");
    check(called, 1'b1, "function-call wrapper");
    check(streamed, 1'b0, "streaming wrapper");
    check(postselected, 1'b0, "post-select wrapper");

    #1.1;
    check(delayed, 1'b0, "initial delay delivered");
    bus.source = 1'b1;

    #0.1;
    check(resolved, 1'b1, "weak one reacts immediately");
    check(delayed, 1'b0, "rise delay pending");
    check(concat_hi, 1'b1, "concat lvalue high reacts");
    check(concat_lo, 1'b0, "concat lvalue low reacts");
    check(called, 1'b0, "function-call wrapper reacts");
    check(streamed, 1'b1, "streaming wrapper reacts");
    check(postselected, 1'b1, "post-select wrapper reacts");
    #2;
    check(delayed, 1'b1, "rise delay delivered");

    strong_enable = 1'b1;
    #0.1;
    check(resolved, 1'b0, "strong zero overrides weak one");

    bus.source = 1'b0;
    #0.1;
    check(delayed, 1'b1, "fall delay pending");
    #2;
    check(delayed, 1'b0, "fall delay delivered");

    $display("PASSED");
  end
endmodule
