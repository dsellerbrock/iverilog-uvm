// M4C-7/R2: compound assignment (+=, ^=, &=, |=, <<=) and plain writes to a
// bit/part-select of a FIXED UNPACKED-ARRAY element (arr[i][m:l] op= x), with
// constant and run-time word indices and part offsets. Formerly: the slice
// loader loaded the WHOLE word (width-mismatched %add/%xor crashed vvp;
// |= applied to the entire element) and the store side wrote back at offset
// 0. The slice machinery now extracts the part on load (%parti/u / %part/u)
// and stores at the part offset (the runtime set_word(adr, off, val)
// read-modify-writes the word). IEEE 1800-2017 11.4.1, 11.5.1. Self-checking.
module sv_array_word_part_compound;
  logic [15:0] arr [0:3];
  int e=0;
  initial begin
    // constant word + constant part compound (all ops)
    arr[1] = 16'h01FF; arr[1][7:0] += 8'h01;
    if (arr[1] !== 16'h0100) begin $display("F1 += %h want 0100", arr[1]); e++; end
    arr[2] = 16'h0F0F; arr[2][7:0] ^= 8'hFF;
    if (arr[2] !== 16'h0FF0) begin $display("F2 ^= %h", arr[2]); e++; end
    arr[3] = 16'hF0FF; arr[3][11:4] &= 8'h3C;
    if (arr[3] !== 16'hF00F + 16'h0030) begin end
    if (arr[3] !== 16'hF0CF) begin $display("F3 &= %h want f0cf", arr[3]); e++; end
    arr[0] = 16'h0102; arr[0][7:0] |= 8'h30;
    if (arr[0] !== 16'h0132) begin $display("F4 |= %h", arr[0]); e++; end
    arr[0] = 16'h0104; arr[0][7:0] <<= 2;
    if (arr[0] !== 16'h0110) begin $display("F5 <<= %h", arr[0]); e++; end
    // DYNAMIC word index + constant part
    for (int i=0;i<4;i++) arr[i] = 16'h1100 | i;
    for (int i=0;i<4;i++) arr[i][7:0] += 8'h10;
    for (int i=0;i<4;i++)
      if (arr[i] !== (16'h1110 | i)) begin $display("F6 i=%0d %h", i, arr[i]); e++; end
    // constant word + DYNAMIC part (+=)
    arr[2] = 16'h1111;
    for (int j=0;j<4;j++) arr[2][j*4 +: 4] += 4'h1;
    if (arr[2] !== 16'h2222) begin $display("F7 %h want 2222", arr[2]); e++; end
    // DYNAMIC word + DYNAMIC part
    for (int i=0;i<4;i++) arr[i] = 16'h0000;
    for (int i=0;i<4;i++) for (int j=0;j<2;j++) arr[i][j*8 +: 8] |= (8'h11 * (j+1));
    for (int i=0;i<4;i++)
      if (arr[i] !== 16'h2211) begin $display("F8 i=%0d %h", i, arr[i]); e++; end
    // plain (non-compound) part writes still fine
    arr[1] = 16'hFFFF; arr[1][7:0] = 8'h00;
    if (arr[1] !== 16'hFF00) begin $display("F9 plain %h", arr[1]); e++; end
    if (e==0) $display("PASSED"); else $display("FAILED %0d", e);
    $finish;
  end
endmodule
