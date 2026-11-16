// IEEE 1800-2023 32.4.4: a PORT delay is "the delay from all sources on the
// net to that port"; an INTERCONNECT whose source is not on the load's net
// is "annotated anyway". u1 (PORT), u2 (NETDELAY) and u3 (INTERCONNECT from
// an unrelated port) are driven by a reg, so no module port is a source;
// u4 is the control, driven through a module output. Each load gets 5 ns
// on top of the 1 ns path delay.
`timescale 1ns/1ns
module leaf(input a, output y); assign y = a; specify (a => y) = 1; endspecify endmodule
module drv(input i, output o); assign o = i; endmodule
module dummy(output o); assign o = 1'b0; endmodule
module issue2911_sdf_load_no_port_source;
  reg a = 0;
  wire m, y1, y2, y3, y4, xo;
  leaf u1(a, y1);
  leaf u2(a, y2);
  leaf u3(a, y3);
  drv d0(a, m);
  leaf u4(m, y4);
  dummy x(xo);
  time t1, t2, t3, t4;
  always @(posedge y1) t1 = $time;
  always @(posedge y2) t2 = $time;
  always @(posedge y3) t3 = $time;
  always @(posedge y4) t4 = $time;
  initial begin
    $sdf_annotate("ivltests/issue2911_sdf_load_no_port_source.sdf",
                  issue2911_sdf_load_no_port_source);
    #10 a = 1;
    #20;
    $display("rise u1=%0t u2=%0t u3=%0t u4=%0t", t1, t2, t3, t4);
    // Annotating the same loads again must replace the ABSOLUTE delays,
    // not add a second delay in series.
    $sdf_annotate("ivltests/issue2911_sdf_load_no_port_source.sdf",
                  issue2911_sdf_load_no_port_source);
    a = 0;
    #10 a = 1;
    #20;
    $display("again u1=%0t u2=%0t u3=%0t u4=%0t", t1, t2, t3, t4);
    if (t1 == 46 && t2 == 46 && t3 == 46 && t4 == 46) $display("PASSED");
    else $display("FAILED");
    $finish;
  end
endmodule
