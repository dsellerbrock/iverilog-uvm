// IEEE 1800-2023 39.4.1: assertion system callbacks. Initialized and On
// occur at startup; each vpi_control system operation reports its event;
// End occurs once, after the end of simulation. 39.4.2 per-assertion lock
// and action callbacks on a1 report every change of its control state,
// whether a system operation or $assertcontrol made it.
module sva_vpi_sys_callbacks;
  localparam SYS_ON = 627, SYS_OFF = 628, SYS_RESET = 630, SYS_KILL = 632,
	     SYS_LOCK = 647, SYS_UNLOCK = 648, SYS_ENABLE_PASS = 639,
	     SYS_ENABLE_FAIL = 640, SYS_DISABLE_PASS = 641,
	     SYS_DISABLE_FAIL = 642, SYS_ENABLE_NONVAC = 643,
	     SYS_DISABLE_VAC = 644;
  logic clk = 0;
  always #5 clk = ~clk;
  a1: assert property (@(posedge clk) 1);

  initial begin
    #1 $sva_assert_cbs("sva_vpi_sys_callbacks.a1");
    #9 $sva_sys(SYS_OFF);
    #10 $sva_sys(SYS_KILL);
    #10 $sva_sys(SYS_ON);
    #10 $sva_sys(SYS_LOCK);
    #10 $sva_sys(SYS_UNLOCK);
    #10 $sva_sys(SYS_DISABLE_PASS);
    $sva_sys(SYS_ENABLE_PASS);
    $sva_sys(SYS_DISABLE_FAIL);
    $sva_sys(SYS_ENABLE_FAIL);
    $sva_sys(SYS_DISABLE_VAC);
    $sva_sys(SYS_ENABLE_NONVAC);
    #10 $sva_sys(SYS_RESET);
    #5 $assertcontrol(1, 255, 7, 0, a1);   // Lock
    $assertcontrol(2, 255, 7, 0, a1);      // Unlock
    $assertpassoff(0, a1);
    $assertpassoff(0, a1);                 // no change: no callback
    $assertfailoff(0, a1);
    $assertfailon(0, a1);
    $assertpasson(0, a1);
    #5 $finish;
  end
endmodule
