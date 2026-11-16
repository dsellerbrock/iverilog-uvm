`timescale 1ns/1ns
module issue1573_init_src(input a, output y); assign y = a; endmodule
module issue1573_init_dst(input a, output y); assign y = a; endmodule
module issue1573_initial_pulses;
  reg a = 0;
  reg b = 1'bx;
  wire link, y, link_b, y_b;
  reg rejecting = 1;
  issue1573_init_src s(a, link);
  issue1573_init_dst d(link, y);
  issue1573_init_src s_b(b, link_b);
  issue1573_init_dst d_b(link_b, y_b);
  initial begin
    #1 b = 0;
    repeat (32) #1 b = ~b;
    #11;
    if (y_b !== 0) $fatal(1, "delayed initialization final value: %b", y_b);
  end
  initial begin
    $sdf_annotate("ivltests/issue1573_initial_pulses.sdf", issue1573_initial_pulses);
    repeat (32) #1 a = ~a;
    #11;
    if (y !== 0) $fatal(1, "final value: %b", y);
    #1 a = 1;
    #1 a = 0;
    #11;
    if (y !== 0) $fatal(1, "isolated pulse escaped");
    rejecting = 0;
    a = 1;
    #11;
    if (y !== 1) $fatal(1, "stable rising transition did not propagate");
    a = 0;
    #11;
    if (y !== 0) $fatal(1, "stable falling transition did not propagate");
    $display("PASS");
    $finish;
  end
  always @(y) if (rejecting && y === 1)
    $fatal(1, "sub-reject pulse escaped at %0t", $time);
  always @(y_b) if (y_b === 1)
    $fatal(1, "delayed initialization pulse escaped at %0t", $time);
endmodule
