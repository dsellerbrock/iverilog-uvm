module top;
  localparam logic [31:0] HEX_VALUE = 32'h_dead_beef;
  localparam logic [11:0] OCT_VALUE = 12'o_7_5_3_1;
  localparam logic [7:0] BIN_VALUE = 8'b_1010_0101;
  localparam int DEC_VALUE = 16'd_1234;

  initial begin
    if (HEX_VALUE !== 32'hdead_beef) $fatal(1, "hex mismatch");
    if (OCT_VALUE !== 12'o7531) $fatal(1, "octal mismatch");
    if (BIN_VALUE !== 8'b1010_0101) $fatal(1, "binary mismatch");
    if (DEC_VALUE != 1234) $fatal(1, "decimal mismatch");
    $display("PASSED");
  end
endmodule
