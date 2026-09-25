module sv_packed_continuous_bit_strength;
  logic strong_value;
  wire [1:0] bus;
  wire peer;
  assign (weak0, weak1) bus[0] = 1'b1;
  assign (weak0, weak1) bus[1] = 1'b1;
  tran t0(bus[0], peer);
  assign (strong0, strong1) peer = strong_value;

  initial begin
    strong_value = 0;
    #1;
    if (bus !== 2'b10 || peer !== 1'b0)
      $fatal(1, "weak driver was strengthened");
    strong_value = 1;
    #1;
    if (bus !== 2'b11 || peer !== 1'b1)
      $fatal(1, "strong value changed incorrectly");
    strong_value = 1'bx;
    #1;
    if (bus !== 2'b1x || peer !== 1'bx)
      $fatal(1, "strong X changed incorrectly");
    strong_value = 1'bz;
    #1;
    if (bus !== 2'b11 || peer !== 1'b1)
      $fatal(1, "weak driver did not resolve through tran");
    $display("PASSED");
    $finish(0);
  end
endmodule
