// IEEE 1800-2017/2023 18.4.2: cyclic variables are solved before rand.
// IEEE 1800-2017 18.5.10 / 2023 18.5.9: ordinary solve-before
// ordering then controls conditional distributions without changing legality.
class ordered_randc_leaf;
  rand bit [1:0] value;
endclass

class full_cycle_item;
  randc bit [1:0] cycle;
  rand bit [1:0] early, late;
  rand ordered_randc_leaf child;
  int posts;
  function new; child = new; endfunction
  function void post_randomize; posts++; endfunction
  constraint order_c { solve early before late; }
  constraint relation_c {
    early == cycle;
    late <= early;
    child.value == late;
  }
endclass

class restricted_cycle_item;
  randc bit [2:0] cycle;
  rand bit [2:0] early, late;
  rand ordered_randc_leaf child;
  function new; child = new; endfunction
  constraint order_c { solve early before late; }
  constraint relation_c {
    cycle inside {3'd1, 3'd3, 3'd5};
    early == cycle;
    late <= early;
    child.value == late[1:0];
  }
endclass

class pair_cycle_item;
  randc bit left, right;
  rand bit early, late;
  rand ordered_randc_leaf child;
  bit coupled;
  function new; child = new; endfunction
  constraint order_c { solve early before late; }
  constraint relation_c {
    if (coupled) left == right;
    early == left;
    late == right;
    child.value == {early, late};
  }
endclass

class conditional_item;
  randc bit cycle;
  rand bit early;
  rand bit [3:0] late;
  rand ordered_randc_leaf child;
  function new; child = new; endfunction
  constraint order_c { solve early before late; }
  constraint relation_c {
    cycle <= early;
    if (!early) late == 0;
    child.value == late[1:0];
  }
endclass

class array_cycle_item;
  randc bit cycles[2];
  rand bit early, late;
  rand ordered_randc_leaf child;
  function new; child = new; endfunction
  constraint order_c { solve early before late; }
  constraint relation_c {
    early == cycles[0];
    late == cycles[1];
    child.value == {early, late};
  }
endclass

class ordered_randc_dist_item;
  randc bit cycle;
  rand bit early, value;
  rand ordered_randc_leaf child;
  function new; child = new; endfunction
  constraint order_c { solve early before value; }
  constraint relation_c {
    cycle <= early;
    child.value == {early, value};
    value dist {0 := 1, 1 := 3};
  }
endclass

module test;
  full_cycle_item full = new;
  full_cycle_item replay_a = new;
  full_cycle_item replay_b = new;
  restricted_cycle_item restricted = new;
  pair_cycle_item coupled = new;
  pair_cycle_item independent = new;
  conditional_item conditional = new;
  array_cycle_item array_cycle = new;
  ordered_randc_dist_item dist_item = new;
  bit [3:0] full_seen;
  bit [7:0] restricted_seen;
  bit [1:0] left_seen, right_seen;
  bit [1:0] array0_seen, array1_seen;
  int cycle0_early1;
  int cycle0_count;
  int dist_ones;
  int i;

  initial begin
    full.srandom(32'h46554c4c);
    full.child.srandom(32'h46554c43);
    repeat (4) begin
      if (!full.randomize()) $fatal(1, "full ordered randc solve failed");
      if (full_seen[full.cycle]) $fatal(1, "full cycle repeated early");
      full_seen[full.cycle] = 1;
      if (full.early != full.cycle || full.late > full.early
          || full.child.value != full.late)
        $fatal(1, "full cycle relation failed");
    end
    if (full_seen != 4'b1111 || full.posts != 4)
      $fatal(1, "full cycle incomplete or callback count wrong");

    restricted.srandom(32'h52455354);
    restricted.child.srandom(32'h52455343);
    repeat (3) begin
      if (!restricted.randomize()) $fatal(1, "restricted cycle solve failed");
      if (!(restricted.cycle inside {3'd1,3'd3,3'd5})
          || restricted_seen[restricted.cycle])
        $fatal(1, "restricted cycle repeated or escaped domain");
      restricted_seen[restricted.cycle] = 1;
    end
    if (restricted_seen != 8'b00101010)
      $fatal(1, "restricted cycle incomplete");

    coupled.coupled = 1;
    coupled.srandom(32'h434f5550);
    coupled.child.srandom(32'h434f5543);
    repeat (2) begin
      if (!coupled.randomize() || coupled.left != coupled.right)
        $fatal(1, "coupled randc pair failed");
      if (left_seen[coupled.left] || right_seen[coupled.right])
        $fatal(1, "coupled pair repeated early");
      left_seen[coupled.left] = 1;
      right_seen[coupled.right] = 1;
    end
    if (left_seen != 2'b11 || right_seen != 2'b11)
      $fatal(1, "coupled pair cycles incomplete");

    left_seen = 0;
    right_seen = 0;
    independent.coupled = 0;
    independent.srandom(32'h494e4450);
    independent.child.srandom(32'h494e4443);
    repeat (2) begin
      if (!independent.randomize()) $fatal(1, "independent randc pair failed");
      if (left_seen[independent.left] || right_seen[independent.right])
        $fatal(1, "independent pair repeated early");
      left_seen[independent.left] = 1;
      right_seen[independent.right] = 1;
    end

    array_cycle.srandom(32'h41525259);
    array_cycle.child.srandom(32'h41525243);
    repeat (2) begin
      if (!array_cycle.randomize()) $fatal(1, "fixed-array randc solve failed");
      if (array0_seen[array_cycle.cycles[0]]
          || array1_seen[array_cycle.cycles[1]])
        $fatal(1, "fixed-array randc element repeated early");
      array0_seen[array_cycle.cycles[0]] = 1;
      array1_seen[array_cycle.cycles[1]] = 1;
      if (array_cycle.child.value != {array_cycle.early,array_cycle.late})
        $fatal(1, "fixed-array cross-object relation failed");
    end
    if (array0_seen != 2'b11 || array1_seen != 2'b11)
      $fatal(1, "fixed-array randc cycles incomplete");

    // The single ordinary dist subject is conditioned on every proved randc
    // prefix before draws. Its 1:3 marginal remains visible after staging.
    dist_item.srandom(32'h44495354);
    dist_item.child.srandom(32'h44495343);
    repeat (400) begin
      if (!dist_item.randomize()) $fatal(1, "coupled ordinary dist failed");
      if (dist_item.value) dist_ones++;
      if (dist_item.cycle > dist_item.early
          || dist_item.child.value != {dist_item.early,dist_item.value})
        $fatal(1, "coupled ordinary dist relation failed");
    end
    if (dist_ones < 250 || dist_ones > 350)
      $fatal(1, "coupled ordinary dist marginal collapsed: %0d", dist_ones);

    // A disabled cyclic property is state, not an active implicit stage.
    full.cycle = 2'd2;
    full.cycle.rand_mode(0);
    repeat (3) begin
      if (!full.randomize() || full.cycle != 2'd2 || full.early != 2'd2)
        $fatal(1, "disabled randc property was sampled");
    end

    // Equal owner and child seeds replay every staged draw exactly.
    replay_a.srandom(32'h5245504c);
    replay_b.srandom(32'h5245504c);
    replay_a.child.srandom(32'h52455043);
    replay_b.child.srandom(32'h52455043);
    repeat (8) begin
      if (!replay_a.randomize() || !replay_b.randomize())
        $fatal(1, "seeded replay solve failed");
      if (replay_a.cycle != replay_b.cycle
          || replay_a.early != replay_b.early
          || replay_a.late != replay_b.late
          || replay_a.child.value != replay_b.child.value)
        $fatal(1, "seeded ordered-randc replay diverged");
    end

    // randc is first. On cycle==0, early has two legal values and must retain
    // diversity; late is then sampled from the fiber selected by early.
    // Correct staging gives early==1 on half of those 200 calls. Sampling
    // complete tuples instead would weight its 16 suffixes and give 16/17.
    conditional.srandom(32'h434f4e44);
    conditional.child.srandom(32'h434f4e43);
    repeat (400) begin
      if (!conditional.randomize()) $fatal(1, "conditional solve failed");
      if (conditional.cycle == 0) begin
        cycle0_count++;
        if (conditional.early) cycle0_early1++;
      end
      if (conditional.cycle > conditional.early
          || (!conditional.early && conditional.late != 0)
          || conditional.child.value != conditional.late[1:0])
        $fatal(1, "conditional relation failed");
    end
    if (cycle0_count != 200 || cycle0_early1 < 60 || cycle0_early1 > 140)
      $fatal(1, "ordinary conditional distribution collapsed %0d/%0d",
             cycle0_early1, cycle0_count);

    $display("PASSED");
  end
endmodule
