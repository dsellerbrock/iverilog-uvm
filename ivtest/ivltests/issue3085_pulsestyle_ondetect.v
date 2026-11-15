// IEEE 1800-2023 30.7.4.1: with pulsestyle_ondetect, a pulse that is
// filtered to X makes its transition to X "immediately upon detection of
// the pulse"; pulsestyle_onevent (the default) keeps the scheduled time of
// the leading edge. 30.7.4.2: with showcancelled and on-detect, the X of a
// negative pulse also starts at detection.
`timescale 1ns/1ps
module event_style(input a, output y);
  buf(y, a);
  specify
    pulsestyle_onevent y;
    (a => y) = 4;
    specparam PATHPULSE$a$y = (2, 3);
  endspecify
endmodule

module detect_style(input a, output y);
  buf(y, a);
  specify
    pulsestyle_ondetect y;
    (a => y) = 4;
    specparam PATHPULSE$a$y = (2, 3);
  endspecify
endmodule

module cancel_event(input a, output y);
  buf(y, a);
  specify
    showcancelled y;
    (a => y) = (6, 4);
  endspecify
endmodule

module cancel_detect(input a, output y);
  buf(y, a);
  specify
    pulsestyle_ondetect y;
    showcancelled y;
    (a => y) = (6, 4);
  endspecify
endmodule

module top;
  reg a = 0;
  wire ey, dy, cey, cdy;
  int errors = 0;
  event_style e(a, ey);
  detect_style d(a, dy);
  cancel_event ce(a, cey);
  cancel_detect cd(a, cdy);

  task automatic check(input logic got, input logic want, input string what);
    if (got !== want) begin
      $display("FAILED: t=%0t %s = %b, want %b", $time, what, got, want);
      errors += 1;
    end
  endtask

  initial begin
    // A 2 ns pulse through a 4 ns path with reject 2, error 3: filtered
    // to X. Leading edge at 14, trailing at 16, detected at 12.
    #10 a = 1;
    #2 a = 0;
    #1 check(dy, 1'bx, "on-detect y at 13");
       check(ey, 1'b0, "on-event y at 13");
    #2 check(dy, 1'bx, "on-detect y at 15");
       check(ey, 1'bx, "on-event y at 15");
    #2 check(dy, 1'b0, "on-detect y at 17");
       check(ey, 1'b0, "on-event y at 17");

    // A 1 ns pulse through a (6,4) path: the trailing edge (35) is
    // scheduled before the leading edge (36), a negative pulse, detected
    // at 31.
    #13 a = 1;
    #1 a = 0;
    #1 check(cdy, 1'bx, "showcancelled on-detect y at 32");
       check(cey, 1'b0, "showcancelled on-event y at 32");
    #3 check(cdy, 1'bx, "showcancelled on-detect y at 35.5");
    #0.5 check(cey, 1'bx, "showcancelled on-event y at 35.5");
    #1.5 check(cdy, 1'b0, "showcancelled on-detect y at 37");
       check(cey, 1'b0, "showcancelled on-event y at 37");
    if (errors == 0) $display("PASSED");
  end
endmodule
