module top;
  reg [7:0] mem [0:16383];
  integer i;

  initial begin
    for (i = 0; i < 16384; i = i + 1)
      mem[i] = (i * 37 + 11) & 8'hff;
    $indexed_read(4096, 4);
    $display("SV_PASS sram_indexed_backdoor bytes=16384");
    $finish;
  end
endmodule
