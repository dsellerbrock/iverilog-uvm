`timescale 1ns/1ps

module top;
  logic d;
  // Syntax 6-2 permits a drive strength before the implicit data type and
  // pure net delay, even when this declaration has no initializer.
  wire (strong1, pull0) #5 pure_delay;
  wire (strong1, pull0) logic #5 standard_assignment = d;

  // Historical Icarus extension: nonempty data type/range before strength.
  wire logic (strong1, pull0) #5 legacy_assignment = d;
  assign pure_delay = d;

  task automatic check(input logic got, input logic expected,
                       input string where);
    if (got !== expected) begin
      $display("FAILED %s t=%0t got=%b expected=%b", where, $time,
               got, expected);
      $fatal(1);
    end
  endtask

  initial begin
    d = 0;
    #5.001 begin
      check(pure_delay, 0, "pure delay initial fall");
      check(standard_assignment, 0, "standard assignment fall");
      check(legacy_assignment, 0, "legacy assignment fall");
    end
    d = 1;
    #4.999 begin
      check(pure_delay, 0, "pure delay waits");
      check(standard_assignment, 0, "standard assignment waits");
      check(legacy_assignment, 0, "legacy assignment waits");
    end
    #0.002 begin
      check(pure_delay, 1, "pure delay rise");
      check(standard_assignment, 1, "standard assignment rise");
      check(legacy_assignment, 1, "legacy assignment rise");
    end
    $display("PASSED");
  end
endmodule
