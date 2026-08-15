`timescale 1ns/1ps

module top;
  logic [1:0] src;
  wire [1:0] #(7, 3, 5) declaration_assignment = src;
  wire [1:0] #(7, 3, 5) pure_net_delay;
  assign pure_net_delay = src;
  wire [1:0] standalone_assignment;
  assign #(7, 3, 5) standalone_assignment = src;

  task automatic check(input logic [1:0] got, input logic [1:0] expected,
                       input string where);
    if (got !== expected) begin
      $display("FAILED %s t=%0t got=%b expected=%b", where, $time,
               got, expected);
      $fatal(1);
    end
  endtask

  initial begin
    src = 2'b00;
    #3.001;
    check(declaration_assignment, 2'b00, "declaration initial fall");
    check(pure_net_delay, 2'b00, "pure initial fall");
    check(standalone_assignment, 2'b00, "standalone initial fall");

    src = 2'b01;
    #7.001;
    src = 2'b10;
    #3.001 begin
      check(declaration_assignment, 2'b01, "declaration is whole vector");
      check(standalone_assignment, 2'b01, "standalone is whole vector");
      check(pure_net_delay, 2'b00, "pure delay applies per bit");
    end
    #4 begin
      check(declaration_assignment, 2'b10, "declaration rise target");
      check(standalone_assignment, 2'b10, "standalone rise target");
      check(pure_net_delay, 2'b10, "pure mixed target complete");
    end

    src = 2'bx0;
    #3.001 check(pure_net_delay, 2'bx0, "pure X uses table minimum");
    #3.999 begin
      check(declaration_assignment, 2'bx0, "declaration X uses rise");
      check(standalone_assignment, 2'bx0, "standalone X uses rise");
    end
    src = 2'bzz;
    #5.001 begin
      check(declaration_assignment, 2'bzz, "declaration all-Z turnoff");
      check(standalone_assignment, 2'bzz, "standalone all-Z turnoff");
      check(pure_net_delay, 2'bzz, "pure per-bit turnoff");
    end
    $display("PASSED");
  end
endmodule
