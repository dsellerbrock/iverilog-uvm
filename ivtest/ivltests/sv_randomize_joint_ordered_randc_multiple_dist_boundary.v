class md_leaf;
  rand bit [7:0] value;
endclass

class md_zero_exclusion;
  randc bit cycle;
  rand bit early, first, second;
  rand md_leaf child;
  function new; child = new; endfunction
  constraint order_c { solve early before first; }
  constraint c {
    early == cycle;
    first == early;
    second == first;
    child.value == second;
    first dist {0 := 1, 1 := 1};
    second dist {0 := 1, 1 := 0};
  }
endclass

class md_prefix_exclusion;
  randc bit cycle;
  rand bit early;
  rand bit [1:0] first, second;
  rand md_leaf child;
  function new; child = new; endfunction
  constraint order_c { solve early before first; }
  constraint c {
    early == cycle;
    first == cycle;
    second == first;
    child.value == second;
    first dist {[0:1] := 1};
    second dist {0 := 1, 1 := 3};
  }
endclass

class md_rollback;
  randc bit cycle;
  rand bit early, first, second;
  rand md_leaf child;
  int posts;
  function new; child = new; endfunction
  function void post_randomize; posts++; endfunction
  constraint order_c { solve early before first; }
  constraint c {
    cycle <= early;
    first <= early;
    second == first;
    child.value == second;
    first dist {0 := 1, 1 := 3};
    second dist {0 := 3, 1 := 1};
  }
endclass

class md_unordered_large;
  randc bit cycle;
  rand bit first, second;
  rand bit [9:0] data;
  rand md_leaf child;
  function new; child = new; endfunction
  constraint c {
    cycle <= data[2];
    first == data[0];
    second == data[1];
    child.value == data[9:2];
    first dist {0 := 1, 1 := 3};
    second dist {0 := 3, 1 := 1};
  }
endclass

class md_cap;
  randc bit cycle;
  rand bit gate, first, second;
  rand bit [9:0] data;
  rand md_leaf child;
  int posts;
  function new; child = new; endfunction
  function void post_randomize; posts++; endfunction
  constraint order_c { solve gate before data; }
  constraint c {
    cycle <= data[2];
    gate == data[3];
    first == data[0];
    second == data[1];
    child.value == data[9:2];
    first dist {0 := 1, 1 := 3};
    second dist {0 := 3, 1 := 1};
  }
endclass

module test;
  md_zero_exclusion zero_item = new;
  md_prefix_exclusion excluded = new;
  md_rollback subject = new;
  md_rollback control = new;
  md_cap cap = new;
  md_unordered_large unordered_large = new;
  bit [1:0] seen;
  string root_rng, child_rng;
  bit old_cycle, old_early, old_first, old_second;
  bit [7:0] old_child;

  initial begin
    zero_item.srandom(32'h5a45524f);
    zero_item.child.srandom(32'h5a455243);
    repeat (4) begin
      if (!zero_item.randomize()) $fatal(1,"zero-weight hard domain rejected");
      if (zero_item.cycle != 0 || zero_item.early != 0
          || zero_item.first != 0 || zero_item.second != 0
          || zero_item.child.value != 0)
        $fatal(1,"zero-weight exclusion was not preserved");
    end

    excluded.srandom(32'h4558434c);
    excluded.child.srandom(32'h45584343);
    repeat (2) begin
      if (!excluded.randomize()) $fatal(1,"positive excluded-range fiber rejected");
      if (seen[excluded.cycle]) $fatal(1,"prefix randc cycle repeated");
      seen[excluded.cycle] = 1;
      if (excluded.first != excluded.cycle
          || excluded.second != excluded.first
          || excluded.child.value != excluded.second)
        $fatal(1,"prefix exclusion relation failed");
    end
    if (seen != 2'b11) $fatal(1,"prefix cycle incomplete");

    subject.cycle=1; subject.early=1; subject.first=1; subject.second=1;
    subject.child.value=1;
    subject.srandom(32'h524f4c4c); subject.child.srandom(32'h524f4c43);
    old_cycle=subject.cycle; old_early=subject.early;
    old_first=subject.first; old_second=subject.second;
    old_child=subject.child.value;
    root_rng=subject.get_randstate(); child_rng=subject.child.get_randstate();
    if (subject.randomize() with {1'b0;}) $fatal(1,"UNSAT solve succeeded");
    if (subject.cycle!==old_cycle || subject.early!==old_early
        || subject.first!==old_first || subject.second!==old_second
        || subject.child.value!==old_child || subject.posts!=0)
      $fatal(1,"UNSAT changed values/callbacks");
    if (subject.get_randstate()!=root_rng || subject.child.get_randstate()!=child_rng)
      $fatal(1,"UNSAT changed RNG");

    control.cycle=old_cycle; control.early=old_early;
    control.first=old_first; control.second=old_second;
    control.child.value=old_child;
    control.srandom(32'h524f4c4c); control.child.srandom(32'h524f4c43);
    if (!subject.randomize() || !control.randomize())
      $fatal(1,"post-UNSAT replay solve failed");
    if (subject.cycle!=control.cycle || subject.early!=control.early
        || subject.first!=control.first || subject.second!=control.second
        || subject.child.value!=control.child.value)
      $fatal(1,"UNSAT consumed randc history or RNG");

    // With no explicit order, this formerly-supported component has 1536
    // complete tuples before randc is selected. The new ordered-only table
    // proof must not impose its cap on this legacy path.
    unordered_large.srandom(32'h554e4f52);
    unordered_large.child.srandom(32'h554e4f43);
    repeat (4)
      if (!unordered_large.randomize())
        $fatal(1,"unordered large multi-dist randc regressed");

    cap.cycle=1; cap.gate=1; cap.first=1; cap.second=1;
    cap.data=10'h3ff; cap.child.value=8'hff;
    cap.srandom(32'h43415052); cap.child.srandom(32'h43415043);
    root_rng=cap.get_randstate(); child_rng=cap.child.get_randstate();
    // cycle<=data[2] leaves 1536 complete tuples, above the fixed 1024 cap.
    if (cap.randomize()) $fatal(1,"over-cap solve succeeded");
    if (cap.cycle!==1 || cap.gate!==1 || cap.first!==1 || cap.second!==1
        || cap.data!==10'h3ff || cap.child.value!==8'hff || cap.posts!=0)
      $fatal(1,"cap failure changed values/callbacks");
    if (cap.get_randstate()!=root_rng || cap.child.get_randstate()!=child_rng)
      $fatal(1,"cap failure changed RNG before preflight");

    $display("PASSED");
  end
endmodule
