// IEEE 1800-2017/2023 31.4.2 and 31.4.3: the event_based_flag and
// remain_active_flag arguments of $timeskew and $fullskew. The flags
// are parameters, so each instance selects its mode at run time.
`timescale 1ns/1ns

module tskew #(parameter EB = 0, RA = 0) (input CP, input CPN, input MODE);
  reg ntfr = 0;
  integer n = 0;
  time at [0:15];
  always @(ntfr) begin at[n] = $time; n = n + 1; end
  specify
    $timeskew(posedge CP &&& MODE, negedge CPN, 50, ntfr, EB, RA);
  endspecify
endmodule

module fskew #(parameter EB = 0, RA = 0) (input CP, input CPN, input MODE);
  reg ntfr = 0;
  integer n = 0;
  time at [0:15];
  always @(ntfr) begin at[n] = $time; n = n + 1; end
  specify
    $fullskew(posedge CP &&& MODE, negedge CPN, 50, 70, ntfr, EB, RA);
  endspecify
endmodule

module top;
  // Figure 31-1: A=10, B=60, C..E=70..90, F=100 (MODE false), G..J=110..140.
  reg cp1 = 0, cpn1 = 1, mode1 = 1;
  // Figure 31-2: A=10, F=30 (MODE false), B=60, C..G=70..100.
  reg cp2 = 0, cpn2 = 1, mode2 = 1;
  // $fullskew, limits 50 (CP first) and 70 (CPN first).
  reg cp3 = 0, cpn3 = 1, mode3 = 1;

  tskew #(0, 0) t1_00(cp1, cpn1, mode1);
  tskew #(1, 0) t1_10(cp1, cpn1, mode1);
  tskew #(1, 1) t1_11(cp1, cpn1, mode1);
  tskew #(0, 1) t1_01(cp1, cpn1, mode1);
  tskew #(0, 0) t2_00(cp2, cpn2, mode2);
  tskew #(1, 0) t2_10(cp2, cpn2, mode2);
  tskew #(1, 1) t2_11(cp2, cpn2, mode2);
  tskew #(0, 1) t2_01(cp2, cpn2, mode2);
  fskew #(0, 0) f_00(cp3, cpn3, mode3);
  fskew #(0, 1) f_01(cp3, cpn3, mode3);
  fskew #(1, 0) f_10(cp3, cpn3, mode3);
  fskew #(1, 1) f_11(cp3, cpn3, mode3);

  task pulse_cp1(input time t); begin #(t - $time) cp1 = 1; #2 cp1 = 0; end endtask
  task pulse_cpn1(input time t); begin #(t - $time) cpn1 = 0; #2 cpn1 = 1; end endtask

  initial begin
    pulse_cp1(10);
    pulse_cpn1(70); pulse_cpn1(80); pulse_cpn1(90);
    #(95 - $time) mode1 = 0;
    pulse_cp1(100);
    pulse_cpn1(110); pulse_cpn1(120); pulse_cpn1(130); pulse_cpn1(140);
  end

  initial begin
    #10 cp2 = 1; #2 cp2 = 0;
    #13 mode2 = 0; #5 cp2 = 1; #2 cp2 = 0;
    #38 cpn2 = 0; #2 cpn2 = 1; #8 cpn2 = 0; #2 cpn2 = 1;
    #8 cpn2 = 0; #2 cpn2 = 1; #8 cpn2 = 0; #2 cpn2 = 1;
  end

  initial begin
    #10 cp3 = 1; #2 cp3 = 0;       // 10: CP, window CP-first
    #58 cpn3 = 0; #2 cpn3 = 1;     // 70: CPN late
    #28 cpn3 = 0; #2 cpn3 = 1;     // 100: CPN again, replaces the window
    #48 cp3 = 1; #2 cp3 = 0;       // 150: CP within 70, dormant
    #48 cpn3 = 0; #2 cpn3 = 1;     // 200: CPN, window CPN-first
    #23 mode3 = 0; #5 cp3 = 1; #2 cp3 = 0; #3 mode3 = 1; // 230: CP, MODE false
    #65 cp3 = 1; #2 cp3 = 0;       // 300: CP late
    #193 mode3 = 1; #5 cp3 = 1; #2 cp3 = 0; // 500: CP, window CP-first
    #11 mode3 = 0; #2 cp3 = 1; #2 cp3 = 0; #3 mode3 = 1; // 515: CP, MODE false
    #80 cpn3 = 0; #2 cpn3 = 1;     // 600: CPN
  end

  reg ok = 1;
  task check_fires(input [8*8:1] name, input integer got_n, input integer want_n,
              input time g0, g1, g2, g3, g4, g5, g6,
              input time w0, w1, w2, w3, w4, w5, w6);
    begin
      if (got_n != want_n
          || (want_n > 0 && g0 != w0) || (want_n > 1 && g1 != w1)
          || (want_n > 2 && g2 != w2) || (want_n > 3 && g3 != w3)
          || (want_n > 4 && g4 != w4) || (want_n > 5 && g5 != w5)
          || (want_n > 6 && g6 != w6)) begin
        $display("FAILED %0s: %0d violations at %0t %0t %0t %0t %0t %0t %0t",
                 name, got_n, g0, g1, g2, g3, g4, g5, g6);
        ok = 0;
      end
    end
  endtask

`define EXPECT(i, cnt, w0, w1, w2, w3, w4, w5, w6) \
    check_fires(`"i`", i.n, cnt, i.at[0], i.at[1], i.at[2], i.at[3], i.at[4], \
           i.at[5], i.at[6], w0, w1, w2, w3, w4, w5, w6)

  initial begin
    #800;
    // Figure 31-1, cases 1-4.
    `EXPECT(t1_00, 1, 60, 0, 0, 0, 0, 0, 0);
    `EXPECT(t1_10, 1, 70, 0, 0, 0, 0, 0, 0);
    `EXPECT(t1_11, 7, 70, 80, 90, 110, 120, 130, 140);
    `EXPECT(t1_01, 1, 60, 0, 0, 0, 0, 0, 0);
    // Figure 31-2: only remain_active keeps the timer window across F.
    `EXPECT(t2_00, 0, 0, 0, 0, 0, 0, 0, 0);
    `EXPECT(t2_10, 0, 0, 0, 0, 0, 0, 0, 0);
    `EXPECT(t2_11, 4, 70, 80, 90, 100, 0, 0, 0);
    `EXPECT(t2_01, 1, 60, 0, 0, 0, 0, 0, 0);
    // $fullskew, timer- and event-based, with and without remain_active.
    `EXPECT(f_00, 4, 60, 270, 350, 670, 0, 0, 0);
    `EXPECT(f_01, 5, 60, 270, 350, 550, 670, 0, 0);
    `EXPECT(f_10, 2, 70, 300, 0, 0, 0, 0, 0);
    `EXPECT(f_11, 3, 70, 300, 600, 0, 0, 0, 0);
    if (ok) $display("PASSED");
    $finish;
  end
endmodule
