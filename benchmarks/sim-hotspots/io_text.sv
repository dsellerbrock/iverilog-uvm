`timescale 1ns/1ps
module top;
  integer file, i;
  reg [31:0] value;
  initial begin
    file = $fopen("trace.txt", "w");
    value = 32'h12345678;
    for (i = 0; i < 96000; i = i + 1) begin
      value = (value << 3) ^ (value >> 2) ^ i;
      $fwrite(file, "%0d %08h\n", i, value);
    end
    $fclose(file);
    $display("wrote=%0d final=%08h", i, value);
    $finish;
  end
endmodule
