// Unsupported multi-distribution metadata must fail atomically.
class bad_leaf;
  rand bit value;
endclass

class bad_multi;
  rand bad_leaf child;
  rand bit value;
  rand bit weight;
  int posts;

  function new();
    child = new;
    value = 1;
    child.value = 1;
    weight = 0;
  endfunction

  function void post_randomize();
    posts++;
  endfunction

  constraint c {
    child.value == value;
    value dist {0 := 1, 1 := 2};
    child.value dist {0 := (weight+1), 1 := 1};
  }
endclass

class cap_multi;
  rand bad_leaf child;
  rand bit a, b, gate;
  rand bit [10:0] data;
  int posts;

  function new();
    child = new;
    a = 1; b = 1; gate = 0; data = 1;
    child.value = 1;
  endfunction

  function void post_randomize(); posts++; endfunction

  constraint c {
    solve gate before data;
    a == b;
    child.value == b;
    data[0] == a;
    if (!gate) data == 0;
    a dist {0 := 1, 1 := 3};
    b dist {0 := 3, 1 := 1};
  }
endclass

class x_weight_multi;
  rand bad_leaf child;
  rand bit value;
  integer weight = 'x;
  function new(); child = new; value = 1; child.value = 1; endfunction
  constraint c {
    child.value == value;
    value dist {0 := 1, 1 := 2};
    child.value dist {0 := weight, 1 := 1};
  }
endclass

class overflow_weight_multi;
  rand bad_leaf child;
  rand bit value;
  longint unsigned weight = 64'h1_0000_0000;
  function new(); child = new; value = 1; child.value = 1; endfunction
  constraint c {
    child.value == value;
    value dist {0 := 1, 1 := 2};
    child.value dist {0 := weight, 1 := 1};
  }
endclass

class wide_leaf;
  rand bit [9:0] value;
endclass

class range_cap_multi;
  rand wide_leaf child;
  rand bit [9:0] value;
  function new(); child = new; value = 1; child.value = 1; endfunction
  constraint c {
    child.value == value;
    value dist {0 := 1, 1 := 1};
    child.value dist {[0:300] :/ 1};
  }
endclass

class guarded_multi;
  rand bad_leaf child;
  rand bit a, b;
  bit enable = 0;
  function new(); child = new; a = 1; b = 1; child.value = 1; endfunction
  constraint c {
    a == b;
    child.value == b;
    a dist {0 := 1, 1 := 2};
    if (enable) b dist {0 := 2, 1 := 1};
  }
endclass

module main;
  bad_multi item = new;
  cap_multi cap = new;
  x_weight_multi xitem = new;
  overflow_weight_multi overflow = new;
  range_cap_multi range_cap = new;
  guarded_multi guarded = new;
  string root_state, child_state;
  string cap_state, cap_child_state;
  bit guarded_a, guarded_b, guarded_child;

  initial begin
    item.srandom(32'h4241444d);
    item.child.srandom(32'h42414443);
    root_state = item.get_randstate();
    child_state = item.child.get_randstate();
    if (item.randomize()) $fatal(1, "rand-dependent weight admitted");
    if (item.value != 1 || item.child.value != 1 || item.weight != 0
        || item.posts != 0)
      $fatal(1, "failed multiple dist changed object state");
    if (item.get_randstate() != root_state
        || item.child.get_randstate() != child_state)
      $fatal(1, "failed multiple dist changed RNG state");

    cap.srandom(32'h43415052);
    cap.child.srandom(32'h43415043);
    cap_state = cap.get_randstate();
    cap_child_state = cap.child.get_randstate();
    if (cap.randomize())
      $fatal(1, "prefix-dependent over-cap projection admitted");
    if (cap.a != 1 || cap.b != 1 || cap.gate != 0 || cap.data != 1
        || cap.child.value != 1 || cap.posts != 0)
      $fatal(1, "over-cap failure changed object state");
    if (cap.get_randstate() != cap_state
        || cap.child.get_randstate() != cap_child_state)
      $fatal(1, "over-cap failure changed RNG state");

    xitem.srandom(32'h58575254);
    xitem.child.srandom(32'h58574348);
    root_state = xitem.get_randstate();
    child_state = xitem.child.get_randstate();
    if (xitem.randomize() || xitem.value != 1 || xitem.child.value != 1)
      $fatal(1, "X-weight multi-dist was not transactional");
    if (xitem.get_randstate() != root_state
        || xitem.child.get_randstate() != child_state)
      $fatal(1, "X-weight multi-dist changed RNG state");

    overflow.srandom(32'h4f565246);
    overflow.child.srandom(32'h4f564348);
    root_state = overflow.get_randstate();
    child_state = overflow.child.get_randstate();
    if (overflow.randomize() || overflow.value != 1
        || overflow.child.value != 1)
      $fatal(1, "overflow-weight multi-dist was not transactional");
    if (overflow.get_randstate() != root_state
        || overflow.child.get_randstate() != child_state)
      $fatal(1, "overflow-weight multi-dist changed RNG state");

    range_cap.srandom(32'h52414e47);
    range_cap.child.srandom(32'h52414348);
    root_state = range_cap.get_randstate();
    child_state = range_cap.child.get_randstate();
    if (range_cap.randomize() || range_cap.value != 1
        || range_cap.child.value != 1)
      $fatal(1, "range-cap multi-dist was not transactional");
    if (range_cap.get_randstate() != root_state
        || range_cap.child.get_randstate() != child_state)
      $fatal(1, "range-cap multi-dist changed RNG state");

    guarded.srandom(32'h47554152);
    guarded.child.srandom(32'h47554348);
    if (!guarded.randomize() || guarded.a != guarded.b
        || guarded.child.value != guarded.b)
      $fatal(1, "inactive guarded dist was not sifted");
    guarded.enable = 1;
    guarded_a = guarded.a;
    guarded_b = guarded.b;
    guarded_child = guarded.child.value;
    root_state = guarded.get_randstate();
    child_state = guarded.child.get_randstate();
    if (guarded.randomize())
      $fatal(1, "guarded multi-dist was not rejected transactionally");
    if (guarded.a != guarded_a || guarded.b != guarded_b
        || guarded.child.value != guarded_child)
      $fatal(1, "guarded multi-dist changed object state");
    if (guarded.get_randstate() != root_state
        || guarded.child.get_randstate() != child_state)
      $fatal(1, "guarded multi-dist changed RNG state");
    $display("PASSED");
  end
endmodule
