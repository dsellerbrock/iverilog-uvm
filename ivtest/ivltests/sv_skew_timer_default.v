`timescale 1ns/1ns

module main;
  reg a1 = 0, b1 = 0;
  reg a2 = 0, b2 = 0;
  reg a3 = 0, b3 = 0;
  reg a4 = 0, b4 = 0;
  reg a0 = 0, b0 = 0;
  reg a5 = 0, b5 = 0, mode5 = 0;
  reg n1 = 0, n2 = 0, n3 = 0, n4 = 0, n0 = 0, n5 = 0;

  specify
    $timeskew(posedge a1, posedge b1, 2, n1);
    $timeskew(posedge a2, posedge b2, 2, n2);
    $timeskew(posedge a3, posedge b3, 2, n3);
    $fullskew(posedge a4, posedge b4, 2, 2, n4);
    $skew(posedge a0, posedge b0, 2, n0);
    $timeskew(posedge a5 &&& mode5, posedge b5, 2, n5);
  endspecify

  initial begin
    #5 a3 = 1;
    #1 b3 = 1; // An in-limit data event cancels the timer.
    #4 a1 = 1; // No data event: timer reports at t=13.
    #10 a2 = 1; // Late data does not delay the timer report at t=23.
    #10 b2 = 1;
    #10 a4 = 1; // $fullskew also reports without a data event.
    #10 a0 = 1; // $skew remains event-based and silent without data.
    #10 $display("notifiers %b%b%b%b%b", n1, n2, n3, n4, n0);
    #10 mode5 = 1; a5 = 1;
    #1 a5 = 0; mode5 = 0;
    #1 a5 = 1; // False conditioned timestamp makes the check dormant.
    #5 $display("conditioned notifier %b", n5);
    $display("PASSED");
    $finish;
  end
endmodule
