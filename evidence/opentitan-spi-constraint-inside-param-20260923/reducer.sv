// Reduced from spi_device_read_buffer_direct_vseq.sv:94 (released OpenTitan).
module top;
  parameter bit [7:0] READ_CMD_LIST[] = {8'h03, 8'h0b};
  bit [7:0] opcode;
  initial begin
    if (!std::randomize(opcode) with {
          opcode inside {READ_CMD_LIST};
          opcode == 8'h03;
        }) $fatal(1, "unsatisfiable array membership");
    if (opcode != 8'h03) $fatal(1, "incorrect membership result");
    $display("PASS");
  end
endmodule
