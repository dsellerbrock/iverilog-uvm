// IEEE 1800-2023 39.5.1: vpi_control() assertion system control, with a
// NULL scope (all assertions) and with a scope handle. Edges are at 5, 15,
// ..., 105; every control runs between edges.
//
// The action operations have "no effect on any existing attempts". The
// immediate assertion ia5 has no attempt that spans a control, so it is
// exact; the concurrent assertions print a one-time note that their
// lowering applies the change to attempts in progress as well.
module sva_vpi_sys_control_sub(input logic clk, input logic f, output int n);
  a2: assert property (@(posedge clk) f) else n++;
endmodule

module sva_vpi_sys_control_kill(input logic clk, input logic f, output int n);
  // An attempt started at edge e fails at e+20.
  a3: assert property (@(posedge clk) 1 |=> ##1 f) else n++;
endmodule

module sva_vpi_sys_control_imm(input logic clk, input logic f, output int n);
  always @(posedge clk) begin
    ia5: assert (f) else n++;
  end
endmodule

module sva_vpi_sys_control;
  localparam SYS_ON = 627, SYS_OFF = 628, SYS_END = 629, SYS_RESET = 630,
	     SYS_KILL = 632, SYS_LOCK = 647, SYS_UNLOCK = 648,
	     SYS_ENABLE_FAIL = 640, SYS_DISABLE_PASS = 641,
	     SYS_DISABLE_FAIL = 642;
  logic clk = 0;
  always #5 clk = ~clk;
  logic f = 0, t = 1;
  int n1, n2, n3, p4, n5;

  a1: assert property (@(posedge clk) f) else n1++;
  a4: assert property (@(posedge clk) t) p4++;
  sva_vpi_sys_control_sub m (clk, f, n2);
  sva_vpi_sys_control_kill k (clk, f, n3);
  sva_vpi_sys_control_imm im (clk, f, n5);

  initial begin
    #1 $sva_cb_setup("sva_vpi_sys_control.a1");
    #9 $sva_sys(SYS_OFF);            // no attempts at 15, 25, 35
    #10 $sva_sys(SYS_KILL, k);       // k's attempts from 5 and 15 are discarded
    #10 $sva_sys(SYS_LOCK);
    $asserton;                       // locked: no effect
    #10 $sva_sys(SYS_UNLOCK);
    $sva_sys(SYS_ON);                // attempts again from 45
    #10 $sva_sys(SYS_DISABLE_PASS);  // a4's pass actions stop
    $sva_sys(SYS_DISABLE_FAIL, m);   // a2's fail actions stop
    $sva_sys(SYS_DISABLE_FAIL, im);  // ia5's fail actions stop
    #10 $sva_sys(SYS_OFF, m);        // a2 stops at 65
    $sva_sys(SYS_ENABLE_FAIL, im);   // ia5 fails count again from 65
    #6 $sva_cb_dump;
    #4 $sva_sys(SYS_RESET);          // initial state; k's attempts from 55, 65 discarded
    #18 $sva_cb_dump;
    #2 $sva_sys(SYS_END);            // all attempts discarded, callbacks removed
    $asserton;                       // after End: no effect
    #20;
    $display("a1 fail actions: %0d", n1);   // 5, 45, 55, 65, 75, 85
    $display("a2 fail actions: %0d", n2);   // 5, 45, 75, 85
    $display("a3 fail actions: %0d", n3);   // the attempt from 45, at 65
    $display("a4 pass actions: %0d", p4);   // 5, 45, 75, 85
    $display("ia5 fail actions: %0d", n5);  // 5, 45, 65, 75, 85
    $sva_cb_dump;
    $finish;
  end
endmodule
