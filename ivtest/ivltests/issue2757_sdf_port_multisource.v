// Issue #2757: an SDF PORT or NETDELAY delay on the load port of a net with
// two sources is the delay "from all sources on the net to that port"
// (IEEE 1800-2017/2023 32.4.4, Table 32-3), so every source reaches the load
// late; the net itself and an unannotated load stay undelayed.
`timescale 1ns/1ns
module issue2757_drv(input a, input en, output y);
  assign y = en ? a : 1'bz;
endmodule

module issue2757_ld(input a, output y);
  assign y = a;
endmodule

module issue2757_sdf_port_multisource;
  reg a1 = 0, a2 = 0, e1 = 1, e2 = 0;
  tri n1, n2;
  wire py, ny, uy;
  reg failed = 0;

  issue2757_drv d1(.a(a1), .en(e1), .y(n1));
  issue2757_drv d2(.a(a2), .en(e2), .y(n1));
  issue2757_ld port_load(.a(n1), .y(py));
  issue2757_ld plain_load(.a(n1), .y(uy));
  issue2757_drv d3(.a(a1), .en(e1), .y(n2));
  issue2757_drv d4(.a(a2), .en(e2), .y(n2));
  issue2757_ld net_load(.a(n2), .y(ny));

  task check(input exp_py, input exp_ny, input exp_uy);
    if (py !== exp_py || ny !== exp_ny || uy !== exp_uy) begin
      $display("FAILED at %0t: py=%b ny=%b uy=%b, want %b %b %b",
               $time, py, ny, uy, exp_py, exp_ny, exp_uy);
      failed = 1;
    end
  endtask

  initial begin
    $sdf_annotate("ivltests/issue2757_sdf_port_multisource.sdf",
                  issue2757_sdf_port_multisource);
    #10 a1 = 1;                         // first source rises
    #1 check(0, 0, 1);                  // 11: only the plain load sees it
    #3 check(1, 0, 1);                  // 14: PORT delay 3 elapsed
    #2 check(1, 1, 1);                  // 16: NETDELAY 5 elapsed
    #4 e1 = 0; e2 = 1; a2 = 0;          // 20: hand over to the second source
    #1 check(1, 1, 0);
    #3 check(0, 1, 0);                  // 24
    #2 check(0, 0, 0);                  // 26
    #4 a2 = 1;                          // 30: second source rises
    #2 check(0, 0, 1);
    #2 check(1, 0, 1);                  // 34
    #2 check(1, 1, 1);                  // 36
    if (!failed) $display("PASSED");
  end
endmodule
