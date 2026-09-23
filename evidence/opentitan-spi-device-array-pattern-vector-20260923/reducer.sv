// Reduced from OpenTitan SPI Device READ_CMD_LIST use sites.
module top;
  parameter bit [7:0] READ_CMD_LIST[] = {8'h03, 8'h0b};
  bit [7:0] opcode;
  bit [7:0] target_ops[$];
  initial begin
    opcode = 8'h03;
    if (!(opcode inside {READ_CMD_LIST})) $fatal(1, "array membership");
    target_ops = {READ_CMD_LIST};
    if (target_ops.size() != 2 || target_ops[0] != 8'h03 ||
        target_ops[1] != 8'h0b) $fatal(1, "unpacked array concatenation");
    $display("PASS");
  end
endmodule
