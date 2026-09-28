// IEEE 1800-2017/2023 7.4, 7.8: OpenTitan flash_ctrl fixed child slots
// retain their declared nonzero bounds; invalid writes leave values intact.
module top;
  bit [7:0] m[int][2:3];
  initial begin
    m[1][2] = 8'hA5;
    m[1][3] = 8'h5A;
    m[1][1] = 8'hFF;
    if (!m.exists(1) || m[1][2] !== 8'hA5 || m[1][3] !== 8'h5A)
      $fatal(1, "invalid fixed slot changed neighboring values");
    $display("PASSED");
  end
endmodule
