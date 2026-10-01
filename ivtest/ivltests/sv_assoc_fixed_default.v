// IEEE 1800-2017/2023 7.8, 7.9.11: OpenTitan flash_ctrl enum-keyed
// fixed arrays use absent-key reads and default values without insertion.
module top;
  typedef bit [7:0] pair_t[3:2];
  pair_t map[int] = '{default: pair_t'{8'hA5, 8'h5A}};
  initial begin
    if (map.exists(9) || map[9][3] !== 8'hA5
        || map[9][2] !== 8'h5A || map.exists(9))
      $fatal(1, "explicit default read inserted key");
    map[9][2] = 8'h3C;
    if (!map.exists(9) || map[9][3] !== 8'hA5
        || map[9][2] !== 8'h3C)
      $fatal(1, "write did not copy explicit default");
    if (map[10][2] !== 8'h5A || map.exists(10))
      $fatal(1, "stored entry changed shared default");
    $display("PASSED");
  end
endmodule
