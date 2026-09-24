typedef int unsigned uint;

class weighted_coupled_item;
  rand bit [31:0] start_addr;
  rand bit [31:0] end_addr;
  rand uint size;

  constraint order_c { solve start_addr, size before end_addr; }
  constraint address_c {
    start_addr == 32'd1000;
    end_addr == start_addr + size;
    end_addr <= 32'd4000;
  }
  constraint distribution_c {
    size dist {
      [0:5] :/ 2,
      3 :/ 1,
      [6:3000] :/ 3,
      [4001:4010] :/ 11
    };
  }
endclass

class sparse_coupled_item;
  rand bit [31:0] end_addr;
  rand uint size;
  constraint address_c {
    end_addr == size + 1;
    end_addr == 32'd3001;
    size dist {[0:3000] :/ 1};
  }
endclass

module test;
  weighted_coupled_item weighted;
  sparse_coupled_item sparse;
  int low_item_count;
  int overlap_value_count;

  initial begin
    weighted = new;
    weighted.srandom(32'h51a7_2026);
    repeat (128) begin
      if (!weighted.randomize())
        $fatal(1, "multi-item coupled dist randomize failed");
      if (weighted.size > 3000
          || weighted.end_addr != weighted.start_addr + weighted.size)
        $fatal(1, "multi-item result violated hard constraints");
      if (weighted.size <= 5) low_item_count++;
      if (weighted.size == 3) overlap_value_count++;
    end
    // The two active item weights are 2 + 1 + 3. The first two branches
    // select the low region with total probability 1/2; value 3 receives
    // both the range contribution and singleton item contribution.
    if (low_item_count < 44 || low_item_count > 84)
      $fatal(1, "coupled :/ item weight ratio failed: %0d", low_item_count);
    if (overlap_value_count < 16 || overlap_value_count > 44)
      $fatal(1, "overlapping item contribution failed: %0d",
             overlap_value_count);

    sparse = new;
    if (!sparse.randomize() || sparse.size != 3000
        || sparse.end_addr != 3001)
      $fatal(1, "bounded rejection exact fallback failed");
    $display("PASSED");
  end
endmodule
