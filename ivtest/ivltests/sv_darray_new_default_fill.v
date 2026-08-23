// IEEE 1800-2017 7.5.1 and 10.9.1: the size supplied by new[N]
// context-shapes a lone-default assignment pattern. Every new element must
// receive the default value. This is the exact shape used for Caliptra's
// 256-entry firmware write-strobe array.
module main;
  localparam int CALIPTRA_AXI_DATA_WIDTH = 32;
  localparam int FW_NUM_DWORDS = 256;

  logic [CALIPTRA_AXI_DATA_WIDTH/8-1:0] wstrb_array[];
  bit failed;

  initial begin
    failed = 1'b0;
    wstrb_array = new[FW_NUM_DWORDS]
        ('{default:{CALIPTRA_AXI_DATA_WIDTH/8{1'b1}}});

    if (wstrb_array.size() != FW_NUM_DWORDS) begin
      $display("FAILED -- size: got %0d want %0d",
               wstrb_array.size(), FW_NUM_DWORDS);
      failed = 1'b1;
    end

    foreach (wstrb_array[index]) begin
      if (wstrb_array[index] !== '1) begin
        $display("FAILED -- wstrb_array[%0d] = %b",
                 index, wstrb_array[index]);
        failed = 1'b1;
      end
    end

    if (!failed)
      $display("PASSED");
  end
endmodule
