interface issue3542_if;
  logic c, d, q;
  modport flop (input c, d, output q);
endinterface

module issue3542_comb(issue3542_if.flop ch);
  assign ch.q = ch.d & ch.c;
  specify (ch.c => ch.q) = 5; endspecify
endmodule

module issue3542_flop(issue3542_if.flop ch);
  always_ff @(posedge ch.c) ch.q <= ch.d;
  specify
    (posedge ch.c => (ch.q +: ch.d)) = (5, 6);
    $setup(ch.d, posedge ch.c, 1);
  endspecify
endmodule

module top;
  // Emit dut and ff before their interface instances.
  issue3542_if zbus();
  issue3542_if zclkbus();
  issue3542_comb dut(zbus.flop);
  issue3542_flop ff(zclkbus.flop);
  initial begin
    zbus.c = 0; zbus.d = 1;
    zclkbus.c = 0; zclkbus.d = 1;
    #10;
    if (zbus.q !== 0) $fatal(1, "initial output did not settle: %b", zbus.q);
    zbus.c = 1; zclkbus.c = 1;
    #3;
    if (zbus.q !== 0 || zclkbus.q !== 1'bx)
      $fatal(1, "outputs changed before path delay: %b %b", zbus.q, zclkbus.q);
    #3;
    if (zbus.q !== 1 || zclkbus.q !== 1)
      $fatal(1, "outputs did not change after path delay: %b %b", zbus.q, zclkbus.q);
    $display("PASSED");
  end
endmodule
