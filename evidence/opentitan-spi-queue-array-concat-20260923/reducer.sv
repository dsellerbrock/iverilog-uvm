// Reduced from released SPI Device flash_mode_vseq and intercept_vseq.
module top;
  parameter bit [7:0] READ_CMD_LIST[] = {8'h03, 8'h0b};
  bit [7:0] target_ops[$];
  initial begin
    target_ops = {READ_CMD_LIST};
    if (target_ops.size() != 2 || target_ops[0] != 8'h03 ||
        target_ops[1] != 8'h0b) $fatal(1, "queue array concatenation");
    $display("PASS");
  end
endmodule
