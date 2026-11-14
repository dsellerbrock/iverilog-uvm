// IEEE 1800-2023 39.5.1: vpiAssertionSysReset "restores the entire
// assertion system to its initial state", and by default "stepping is
// disabled for all assertions" (39.5.2). So a step enable issued before a
// reset does not survive it: after the reset of u, a newly registered step
// callback on u.x stays silent for the attempt from 25, while the same
// enable on y (outside the reset scope) still steps that attempt at 25 and 35.
// The EnableStep lines print each handle's vpiFullName ("full hierarchical
// name", Annex M): u.x is sva_sys_reset_step.u.x, not u.x.
module sva_sys_reset_step_m(input clk, a, b);
  x: assert property (@(posedge clk) a ##1 b) else ;
endmodule

module sva_sys_reset_step;
  bit clk = 0, a = 1, b = 1;
  always #5 clk = ~clk;

  y: assert property (@(posedge clk) a ##1 b) else ;
  sva_sys_reset_step_m u(clk, a, b);

  initial begin
    #1 $rs_setup;     // EnableStep for start 25 on u.x and y, step callbacks
    #9 $rs_reset;     // vpiAssertionSysReset on scope u
    #1 $rs_rereg;     // step callbacks on u.x again
    #29 $finish(0);
  end
endmodule
