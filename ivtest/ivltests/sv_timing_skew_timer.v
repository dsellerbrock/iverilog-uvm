`timescale 1ns/1ps

module main;
  reg a_missing = 0, b_missing = 0;
  reg a_late = 0, b_late = 0;
  reg a_full = 0, b_full = 0;
  reg a_within = 0, b_within = 0;
  reg a_skew = 0, b_skew = 0;

  specify
    $timeskew(posedge a_missing, posedge b_missing, 2);
    $timeskew(posedge a_late, posedge b_late, 2);
    $fullskew(posedge a_full, posedge b_full, 2, 2);
    $timeskew(posedge a_within, posedge b_within, 2);
    $skew(posedge a_skew, posedge b_skew, 2);
  endspecify

  initial begin
    #10 a_missing = 1;
    #10 a_late = 1;
    #10 a_full = 1;
    #10 a_within = 1;
    #2 b_within = 1;
    #8 b_late = 1;
    #10 $display("PASS: timer-based skew checks");
    $finish;
  end
endmodule
