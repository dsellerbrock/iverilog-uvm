// IEEE 1800-2017/2023 12.7.3: omitting the associative key still permits
// foreach to visit a fixed child rank and the packed leaf rank.
module top;
  bit [2:0] map[int][2:1];
  int seen[2:1][2:0];
  int visits;

  initial begin
    foreach (map[, bank, bit_index]) begin
      if ((bank != 2 && bank != 1) || bit_index < 0 || bit_index > 2)
        $fatal(1, "foreach index out of bounds: %0d,%0d", bank, bit_index);
      if (bank != 2 - visits / 3 || bit_index != 2 - visits % 3)
        $fatal(1, "wrong child traversal order at visit %0d: %0d,%0d",
               visits, bank, bit_index);
      seen[bank][bit_index]++;
      visits++;
    end

    if (visits != 6) $fatal(1, "wrong omitted-key visits: %0d", visits);
    foreach (seen[bank, bit_index])
      if (seen[bank][bit_index] != 1)
        $fatal(1, "wrong packed tail visits at %0d,%0d", bank, bit_index);
    $display("PASSED");
  end
endmodule
