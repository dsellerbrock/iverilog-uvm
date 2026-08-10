// Full-domain exhaustion: each aligned block is one exact permutation.  A
// repeat from the last value of one block to the first of the next is legal,
// so this test deliberately has no cross-boundary inequality assertion.
class randc_txn_full_cycle_item;
  randc bit [1:0] value;
endclass

module test;
  initial begin
    randc_txn_full_cycle_item item;
    bit [3:0] seen;

    item = new;
    item.srandom(32'hc001_d00d);
    for (int cycle = 0; cycle < 32; cycle++) begin
      seen = '0;
      for (int sample = 0; sample < 4; sample++) begin
        if (item.randomize() !== 1)
          $fatal(1, "full-domain randc randomize failed");
        if (seen[item.value])
          $fatal(1, "full-domain randc repeated inside one cycle");
        seen[item.value] = 1'b1;
      end
      if (seen !== 4'b1111)
        $fatal(1, "full-domain randc block was not a permutation");
    end

    $display("PASSED");
  end
endmodule
