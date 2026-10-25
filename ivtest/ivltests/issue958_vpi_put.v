`timescale 1ns/1ps
module issue958_vpi_put;
  localparam integer INERTIAL = 2, TRANSPORT = 3, PURE_TRANSPORT = 4;
  reg [7:0] ia=0, ta=0, pa=0, ib=0, tb=0, pb=0;

  initial begin
    #10;
    $sched(ia, 'h11, 3, INERTIAL); $sched(ta, 'h11, 3, TRANSPORT); $sched(pa, 'h11, 3, PURE_TRANSPORT);
    $sched(ib, 'h11, 3, INERTIAL); $sched(tb, 'h11, 3, TRANSPORT); $sched(pb, 'h11, 3, PURE_TRANSPORT);
    #1;
    $sched(ia, 'h22, 1, INERTIAL); $sched(ta, 'h22, 1, TRANSPORT); $sched(pa, 'h22, 1, PURE_TRANSPORT);
    $sched(ib, 'h22, 5, INERTIAL); $sched(tb, 'h22, 5, TRANSPORT); $sched(pb, 'h22, 5, PURE_TRANSPORT);
    #1;
    if ({ia,ta,pa,ib,tb,pb} !== {8'h22,8'h22,8'h22,8'h00,8'h00,8'h00})
      $fatal(1, "incorrect values at t=12");
    #1;
    $display("t=13 %h %h %h %h %h %h", ia,ta,pa,ib,tb,pb);
    if ({ia,ta,pa,ib,tb,pb} !== {8'h22,8'h22,8'h11,8'h00,8'h11,8'h11})
      $fatal(1, "incorrect values at t=13");
    #1;
    if ({ia,ta,pa,ib,tb,pb} !== {8'h22,8'h22,8'h11,8'h00,8'h11,8'h11})
      $fatal(1, "incorrect values at t=14");
    #1;
    if ({ia,ta,pa,ib,tb,pb} !== {8'h22,8'h22,8'h11,8'h00,8'h11,8'h11})
      $fatal(1, "incorrect values at t=15");
    #1;
    if ({ia,ta,pa,ib,tb,pb} !== {8'h22,8'h22,8'h11,8'h22,8'h22,8'h22})
      $fatal(1, "incorrect values at t=16");
    $display("PASSED");
    $finish;
  end
endmodule
