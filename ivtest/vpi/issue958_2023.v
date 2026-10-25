`timescale 1ns/1ps
module top;
  // vpi_user.h delay flags: inertial=2, transport=3, pure transport=4.
  localparam integer INERTIAL = 2, TRANSPORT = 3, PURE_TRANSPORT = 4;
  reg [7:0] ia=0, ta=0, pa=0, ib=0, tb=0, pb=0;
  initial begin
    #10;
    $sched(ia, 'h11, 3, INERTIAL); $sched(ta, 'h11, 3, TRANSPORT); $sched(pa, 'h11, 3, PURE_TRANSPORT);
    $sched(ib, 'h11, 3, INERTIAL); $sched(tb, 'h11, 3, TRANSPORT); $sched(pb, 'h11, 3, PURE_TRANSPORT);
    #1;
    $sched(ia, 'h22, 1, INERTIAL); $sched(ta, 'h22, 1, TRANSPORT); $sched(pa, 'h22, 1, PURE_TRANSPORT);
    $sched(ib, 'h22, 5, INERTIAL); $sched(tb, 'h22, 5, TRANSPORT); $sched(pb, 'h22, 5, PURE_TRANSPORT);
    #1; $display("12 %h %h %h %h %h %h",ia,ta,pa,ib,tb,pb);
    #1; $display("13 %h %h %h %h %h %h",ia,ta,pa,ib,tb,pb);
    #1; $display("14 %h %h %h %h %h %h",ia,ta,pa,ib,tb,pb);
    #1; $display("15 %h %h %h %h %h %h",ia,ta,pa,ib,tb,pb);
    #1; $display("16 %h %h %h %h %h %h",ia,ta,pa,ib,tb,pb);
    $finish;
  end
endmodule
