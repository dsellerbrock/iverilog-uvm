// Valid combination: dist subjects are ordinary rand, not randc.
class multi_leaf;
  rand bit value;
endclass

class ordered_randc_multi_dist;
  randc bit cycle;
  rand bit early, first, second;
  rand multi_leaf child;
  int posts;
  function new; child = new; endfunction
  function void post_randomize; posts++; endfunction
  constraint order_c { solve early before first; }
  constraint relation_c {
    cycle <= early;
    first <= early;
    first == second;
    child.value == second;
    first dist {0 := 1, 1 := 3};
    second dist {0 := 3, 1 := 1};
  }
endclass

class ordered_randc_signed_multi_dist;
  randc bit cycle;
  rand bit early;
  rand integer first, second;
  rand multi_leaf child;
  function new; child = new; endfunction
  constraint order_c { solve early before first; }
  constraint relation_c {
    early == cycle;
    if (!cycle) first == -1; else first == 1;
    second == first;
    child.value == first[0];
    first dist {8'shff := 1, 8'sh01 := 3};
    second dist {[8'shfe:8'shff] := 1, 8'sh01 := 1};
  }
endclass

module test;
  ordered_randc_multi_dist item = new;
  ordered_randc_multi_dist replay = new;
  ordered_randc_signed_multi_dist signed_item = new;
  int eligible_count, eligible_ones;
  int i;
  initial begin
    item.srandom(32'h4d554c54);
    item.child.srandom(32'h4d554c43);
    replay.srandom(32'h4d554c54);
    replay.child.srandom(32'h4d554c43);
    repeat (400) begin
      if (!item.randomize() || !replay.randomize())
        $fatal(1, "valid ordered randc plus multiple ordinary dist rejected");
      if (item.cycle != replay.cycle || item.early != replay.early
          || item.first != replay.first || item.second != replay.second
          || item.child.value != replay.child.value)
        $fatal(1, "seeded multi-dist replay diverged");
      if (item.cycle > item.early || item.first > item.early
          || item.first != item.second || item.child.value != item.second)
        $fatal(1, "relation violated");
      if (!item.cycle && item.early) begin
        eligible_count++;
        if (item.first) eligible_ones++;
      end
    end
    // With cycle==0 and the earlier variable early==1, first remains free.
    // Stable IR order gives first its 1:3 marginal; equality then fixes second.
    if (eligible_count < 60 || eligible_count > 140
        || eligible_ones * 100 < eligible_count * 55
        || eligible_ones * 100 > eligible_count * 90)
      $fatal(1, "conditional multi-dist marginal collapsed %0d/%0d",
             eligible_ones, eligible_count);
    if (item.posts != 400) $fatal(1, "callback count wrong");

    signed_item.srandom(32'h5349474e);
    signed_item.child.srandom(32'h53494743);
    repeat (2) begin
      if (!signed_item.randomize())
        $fatal(1,"signed mixed-width multi-dist rejected");
      if ((!signed_item.cycle && signed_item.first != -1)
          || (signed_item.cycle && signed_item.first != 1)
          || signed_item.second != signed_item.first
          || signed_item.child.value != signed_item.first[0])
        $fatal(1,"signed mixed-width value mismatch");
    end
    $display("PASSED");
  end
endmodule
