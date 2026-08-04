// IEEE 1800-2017 23.8: $root prefixes an absolute hierarchical path.
// Reduced from OpenTitan i2c_protocol_cov.sv:
//   `define I2C_HIER $root.tb.dut.i2c_core
module leaf;
  logic [3:0] q;
  initial q = 4'hA;
endmodule

module mid;
  leaf l();
  logic [3:0] got;
  initial begin
    #1 got = $root.main.dut.l.q;
    if (got !== 4'hA) $display("FAILED got=%h", got);
    else $display("PASSED");
  end
endmodule

module main;
  mid dut();
endmodule
