module test;
  logic [7:0] src8;
  bit [7:0] dst8;
  logic [128:0] srcw;
  bit [0:0] dst1;
  bit [62:0] dst63;
  bit [63:0] dst64;
  bit [64:0] dst65;
  bit [126:0] dst127;
  bit [127:0] dst128;
  bit [128:0] dst129;
  integer pattern, idx, state;

  initial begin
    for (pattern = 0; pattern < 65536; pattern = pattern + 1) begin
      for (idx = 0; idx < 8; idx = idx + 1) begin
        state = (pattern >> (2 * idx)) & 3;
        case (state)
          0: src8[idx] = 1'b0;
          1: src8[idx] = 1'b1;
          2: src8[idx] = 1'bx;
          3: src8[idx] = 1'bz;
        endcase
      end
      dst8 = src8;
      for (idx = 0; idx < 8; idx = idx + 1) begin
        state = (pattern >> (2 * idx)) & 3;
        if (dst8[idx] !== (state == 1))
          $fatal(1, "8-bit cast mismatch pattern=%0d bit=%0d", pattern, idx);
      end
    end

    for (idx = 0; idx < 129; idx = idx + 1) begin
      case (idx % 4)
        0: srcw[idx] = 1'b0;
        1: srcw[idx] = 1'b1;
        2: srcw[idx] = 1'bx;
        3: srcw[idx] = 1'bz;
      endcase
    end
    dst1 = srcw[0:0];
    dst63 = srcw[62:0];
    dst64 = srcw[63:0];
    dst65 = srcw[64:0];
    dst127 = srcw[126:0];
    dst128 = srcw[127:0];
    dst129 = srcw[128:0];
    for (idx = 0; idx < 129; idx = idx + 1) begin
      if (idx < 1 && dst1[idx] !== (srcw[idx] === 1'b1))
        $fatal(1, "1-bit cast mismatch at bit=%0d", idx);
      if (idx < 63 && dst63[idx] !== (srcw[idx] === 1'b1))
        $fatal(1, "63-bit cast mismatch at bit=%0d", idx);
      if (idx < 64 && dst64[idx] !== (srcw[idx] === 1'b1))
        $fatal(1, "64-bit cast mismatch at bit=%0d", idx);
      if (idx < 65 && dst65[idx] !== (srcw[idx] === 1'b1))
        $fatal(1, "65-bit cast mismatch at bit=%0d", idx);
      if (idx < 127 && dst127[idx] !== (srcw[idx] === 1'b1))
        $fatal(1, "127-bit cast mismatch at bit=%0d", idx);
      if (idx < 128 && dst128[idx] !== (srcw[idx] === 1'b1))
        $fatal(1, "128-bit cast mismatch at bit=%0d", idx);
      if (dst129[idx] !== (srcw[idx] === 1'b1))
        $fatal(1, "129-bit cast mismatch at bit=%0d", idx);
    end
    $display("PASSED");
  end
endmodule
