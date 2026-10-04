module top;
  reg [7:0] mem [0:16383];
  integer i;

  initial begin
    for (i = 0; i < 16384; i = i + 1)
      mem[i] = (i * 37 + 11) & 8'hff;
    $name_read32(256, 16);
    $display("SV_PASS flash_backdoor bytes=16384");
    $finish;
  end
endmodule
