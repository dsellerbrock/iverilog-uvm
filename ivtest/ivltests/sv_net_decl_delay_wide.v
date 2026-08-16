`timescale 1ns/1ps

module top;
  localparam int WIDTH = 65536;
  logic [WIDTH-1:0] drive;
  wire [WIDTH-1:0] #5 delayed;
  assign delayed = drive;

  task automatic expect_all(input logic value, input string where);
    if (delayed !== {WIDTH{value}}) begin
      $display("FAILED %s t=%0t", where, $time);
      $fatal(1);
    end
  endtask

  initial begin
    drive = '0;
    #5.001 expect_all(0, "initial wide enqueue");

    drive = '1;
    #1 drive = '0;
    #1 drive = '1;
    #2.999 expect_all(0, "replacement has not fired early");
    #2.002 expect_all(1, "replacement survives stale empty wake");

    drive = '0;
    #1 drive = '1;
    #1 drive = '0;
    #4.999 expect_all(1, "second cancellation remains inertial");
    #0.002 expect_all(0, "second replacement delivered");
    $display("PASSED");
  end
endmodule
