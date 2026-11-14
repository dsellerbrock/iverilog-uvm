module top;
  logic [5:0] v = 6'b10xz11;
  logic [39:0] ctrl;
  initial begin
    ctrl = 40'b1x;
    if ($countbits(v, 1'b0) != 1 ||
        $countbits(v, 2'b10) != 1 ||
        $countbits(v, 2'b01) != 3 ||
        $countbits(v, 2'b0x) != 1 ||
        $countbits(v, 2'b1z) != 1 ||
        $countbits(v, ctrl) != 1 ||
        $countbits(v, 2'b0x, 2'b1x, 2'b0z) != 2) begin
      $display("FAILED");
      $finish;
    end
    ctrl = 40'b11;
    if ($countbits(v, ctrl) != 3) $display("FAILED variable");
    else $display("PASSED");
  end
endmodule
