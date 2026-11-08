// IEEE 1800-2017/2023 32.4.4: on a multisource net each source/load pair
// can carry its own INTERCONNECT delay. u1.y and u2.y both drive n; the
// load u3.a sees u1 3 ns late and u2 5 ns late, while the net itself and
// the unannotated load u4.a see every source undelayed.
`timescale 1ns/1ns
module drv(input a, input en, output y);
  assign y = en ? a : 1'bz;
endmodule

module ld(input a, output y);
  assign y = a;
endmodule

module tb;
  reg a1 = 0, a2 = 0, e1 = 1, e2 = 0;
  tri n;
  wire y3, y4;
  reg ok = 1;
  drv u1(.a(a1), .en(e1), .y(n));
  drv u2(.a(a2), .en(e2), .y(n));
  ld u3(.a(n), .y(y3));
  ld u4(.a(n), .y(y4));

  task check(input [8*3:1] what, input got, input want);
    if (got !== want) begin
      $display("FAILED at %0t: %0s = %b, expected %b", $time, what, got, want);
      ok = 0;
    end
  endtask

  task at(input time t);
    #(t - $time);
  endtask

  initial begin
    $sdf_annotate("ivltests/issue1567_multisource_interconnect.sdf", tb);
    at(10); a1 = 1;                   // u1 drives 1
    at(11); check("n", n, 1'b1); check("y4", y4, 1'b1); check("y3", y3, 1'b0);
    at(12); check("y3", y3, 1'b0);     // u1 is 3 ns behind at u3
    at(14); check("y3", y3, 1'b1);
    at(20); e1 = 0; e2 = 1;           // u1 releases, u2 drives 0
    at(21); check("n", n, 1'b0); check("y4", y4, 1'b0); check("y3", y3, 1'b1);
    at(24); check("y3", y3, 1'bz);     // u1's release arrived, u2's 0 not yet
    at(26); check("y3", y3, 1'b0);     // u2's 0 arrives 5 ns late
    at(30); a2 = 1;                   // u2 drives 1
    at(31); check("y4", y4, 1'b1); check("y3", y3, 1'b0);
    at(34); check("y3", y3, 1'b0);
    at(36); check("y3", y3, 1'b1);
    if (ok) $display("PASSED");
    $finish;
  end
endmodule
