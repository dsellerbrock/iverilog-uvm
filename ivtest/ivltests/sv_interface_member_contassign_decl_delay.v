`timescale 1ns/1ps

// A continuous assignment to an interface net member drives the raw side of
// that member's net-declaration delay boundary. The declaration delay must be
// applied once, after resolution, just as it is for an ordinary net.
interface declaration_delay_if;
  wire #2 delayed;
endinterface

module declaration_delay_driver(
  declaration_delay_if bus,
  input logic source
);
  assign bus.delayed = source;
endmodule

module sv_interface_member_contassign_decl_delay;
  declaration_delay_if bus();
  logic source;

  declaration_delay_driver dut(.bus(bus), .source(source));

  task automatic check(input logic got, input logic expected,
                       input string where);
    if (got !== expected) begin
      $display("FAILED %s t=%0t got=%b expected=%b",
               where, $time, got, expected);
      $fatal(1);
    end
  endtask

  initial begin
    source = 1'b0;
    #3;
    check(bus.delayed, 1'b0, "initial value settled");

    source = 1'b1;
    #1;
    check(bus.delayed, 1'b0, "rise remains behind declaration delay");
    #1.1;
    check(bus.delayed, 1'b1, "rise crosses declaration delay");

    source = 1'b0;
    #1;
    check(bus.delayed, 1'b1, "fall remains behind declaration delay");
    #1.1;
    check(bus.delayed, 1'b0, "fall crosses declaration delay");

    $display("PASSED");
  end
endmodule
