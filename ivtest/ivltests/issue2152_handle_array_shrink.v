// Issue #2152: objects that a size constraint drops from a rand array of
// class handles are not part of the randomize() call.
//
// IEEE 1800-2023 18.4: "randomize() does not allocate any class objects. Up
// to the new size, existing class objects are retained and their content
// randomized." 18.6.2: "When obj.randomize() is invoked, it first invokes
// pre_randomize() on obj and also all of its random object members that are
// enabled. After the new random values are computed and assigned,
// randomize() invokes post_randomize() on obj and also all of its random
// object members that are enabled."
//
// So the dropped objects get pre_randomize (they are members when the call
// starts), keep their content and random state, and get no post_randomize.
// The expectation in the issue text (pre=0) contradicted 18.6.2.
module issue2152_handle_array_shrink;
  class lf; rand bit [3:0] v; int pre, post; constraint c { v == 9; }
    function void pre_randomize(); pre++; endfunction
    function void post_randomize(); post++; endfunction endclass
  class dz; rand lf items[]; int k; constraint s { items.size == k; } endclass
  class qz; rand lf items[$]; int k; constraint s { items.size == k; } endclass
  dz d = new;
  qz q = new;
  lf a = new, b = new, e = new, f = new, g = new;
  string b_state, e_state, g_state;
  int failed = 0;

  task check(string what, lf x, int v, int pre, int post);
    if (x.v != v || x.pre != pre || x.post != post) begin
      $display("FAILED: %s is %0d/%0d/%0d, expected %0d/%0d/%0d",
               what, x.v, x.pre, x.post, v, pre, post);
      failed++;
    end
  endtask

  initial begin
    d.items = '{a, b, e};
    d.k = 1;
    b_state = b.get_randstate();
    e_state = e.get_randstate();
    if (!d.randomize()) begin $display("FAILED: d.randomize() returned 0"); failed++; end
    if (d.items.size() != 1 || d.items[0] != a) begin $display("FAILED: d.items"); failed++; end
    check("a", a, 9, 1, 1);
    check("b", b, 0, 1, 0);
    check("e", e, 0, 1, 0);
    if (b.get_randstate() != b_state || e.get_randstate() != e_state) begin
      $display("FAILED: a dropped object's random state changed");
      failed++;
    end

    q.items = '{f, g};
    q.k = 1;
    g_state = g.get_randstate();
    if (!q.randomize()) begin $display("FAILED: q.randomize() returned 0"); failed++; end
    if (q.items.size() != 1 || q.items[0] != f) begin $display("FAILED: q.items"); failed++; end
    check("f", f, 9, 1, 1);
    check("g", g, 0, 1, 0);
    if (g.get_randstate() != g_state) begin $display("FAILED: g's random state changed"); failed++; end

    if (failed == 0) $display("PASSED");
  end
endmodule
