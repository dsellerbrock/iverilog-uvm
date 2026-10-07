// IEEE 1800-2017/2023 18.4.2, 18.6.3 and 18.14.1/18.14.3.
class cyclic_leaf;
  randc bit [1:0] value;
endclass
class cyclic_root;
  rand bit [1:0] value;
  rand cyclic_leaf child;
  bit reject;
  function new(); child = new; endfunction
  constraint c { value <= child.value; !reject; }
endclass
class static_node;
  rand static_node child;
  static randc bit [1:0] value;
  constraint c { value inside {[0:3]}; }
endclass
typedef struct { randc bit [1:0] value; } value_s;
class static_struct_node;
  rand static_struct_node child;
  static rand value_s item;
  constraint c { item.value inside {[0:3]}; }
endclass
class dynamic_randc_child;
  rand bit [10:0] value;
endclass
class dynamic_randc_root;
  randc bit [10:0] values[];
  rand dynamic_randc_child child;
  bit impossible;
  function new(); child = new; endfunction
  constraint c {
    values.size() == 1;
    values[0] inside {[0:1024]};
    values[0] == child.value;
    if (impossible) values[0] == 2047;
  }
endclass
class constrained_wide_randc;
  randc int unsigned value;
  bit impossible;
  constraint legal_c {
    value inside {1, 3, 5};
    if (impossible) value == 0;
  }
endclass
class constrained_graph_wide_randc;
  randc int unsigned value;
  rand dynamic_randc_child child;
  bit impossible;
  function new(); child = new; endfunction
  constraint legal_c {
    value inside {[0:100]};
    value == child.value;
    if (impossible) value == 101;
  }
endclass
class parent_limited_wide_randc_child;
  randc int unsigned value;
endclass
class parent_limited_wide_randc_root;
  rand int unsigned parent_value;
  rand parent_limited_wide_randc_child child;
  bit impossible;
  function new(); child = new; endfunction
  constraint parent_c {
    child.value inside {[0:64]};
    parent_value == child.value;
    if (impossible) child.value == 65;
  }
endclass
module main;
  cyclic_root r = new;
  static_node s = new;
  static_struct_node t = new;
  dynamic_randc_root d = new;
  constrained_wide_randc w = new;
  constrained_graph_wide_randc gw = new;
  parent_limited_wide_randc_root p = new;
  bit [3:0] seen, shared_seen, struct_seen;
  bit [1024:0] dynamic_seen;
  bit [7:0] wide_seen;
  bit [100:0] graph_wide_seen;
  bit [64:0] parent_graph_wide_seen;
  bit [1:0] before_parent, before_child;
  bit [10:0] before_dynamic, before_dynamic_child;
  bit [10:0] before_graph_child;
  int unsigned before_graph_wide;
  int unsigned before_parent_graph_value, before_parent_value;
  string child_state, struct_child_state;
  initial begin
    s.child = new; t.child = new;
    r.srandom(23); r.child.srandom(31);
    s.srandom(23); s.child.srandom(31);
    t.srandom(23); t.child.srandom(31);
    d.srandom(32'h44594331); d.child.srandom(32'h44594332);
    child_state = s.child.get_randstate();
    struct_child_state = t.child.get_randstate();
    repeat (12) begin
      seen = 0; shared_seen = 0; struct_seen = 0;
      repeat (4) begin
        if (!r.randomize()) $fatal(1, "joint randc solve failed");
        if (seen[r.child.value]) $fatal(1, "parent rand broke child randc cycle");
        seen[r.child.value] = 1;
        before_parent = r.value; before_child = r.child.value;
        r.reject = 1;
        if (r.randomize() || r.value != before_parent || r.child.value != before_child)
          $fatal(1, "failed graph changed values");
        r.reject = 0;
        if (!s.randomize()) $fatal(1, "shared randc solve failed");
        if (shared_seen[s.value]) $fatal(1, "shared randc history committed twice");
        shared_seen[s.value] = 1;
        if (!t.randomize()) $fatal(1, "static struct solve failed");
        if (struct_seen[t.item.value]) $fatal(1, "static struct cycle repeated");
        struct_seen[t.item.value] = 1;
      end
      if (seen != 15 || shared_seen != 15 || struct_seen != 15)
        $fatal(1, "incomplete randc cycle");
    end
    if (s.child.get_randstate() != child_state)
      $fatal(1, "static scalar consumed a second object's RNG");
    if (t.child.get_randstate() != struct_child_state)
      $fatal(1, "static struct consumed a second object's RNG");
    for (int i = 0; i < 1025; i++) begin
      if (i == 64) begin
        before_dynamic = d.values[0];
        before_dynamic_child = d.child.value;
        d.impossible = 1;
        if (d.randomize() || d.values[0] != before_dynamic
            || d.child.value != before_dynamic_child)
          $fatal(1, "failed dynamic randc solve changed values");
        d.impossible = 0;
      end
      if (!d.randomize())
        $fatal(1, "graph-coupled dynamic randc solve failed at %0d", i);
      if (d.values.size() != 1 || d.values[0] > 1024
          || d.values[0] != d.child.value)
        $fatal(1, "graph-coupled dynamic randc violated its constraints");
      if (dynamic_seen[d.values[0]])
        $fatal(1, "dynamic randc repeated before its feasible cycle ended");
      dynamic_seen[d.values[0]] = 1;
    end
    if (dynamic_seen !== {1025{1'b1}})
      $fatal(1, "dynamic randc did not cover all 1,025 feasible values");
    if (!d.randomize() || d.values.size() != 1 || d.values[0] > 1024
        || d.values[0] != d.child.value || !dynamic_seen[d.values[0]])
      $fatal(1, "dynamic randc did not reset after exhausting its feasible set");
    w.srandom(32'h1020_3040);
    repeat (12) begin
      wide_seen = 0;
      for (int i = 0; i < 3; i++) begin
        if (!w.randomize()) $fatal(1, "constrained wide randc failed");
        if (!(w.value inside {1, 3, 5}))
          $fatal(1, "constrained wide randc emitted an infeasible value");
        if (wide_seen[w.value])
          $fatal(1, "constrained wide randc repeated inside a cycle");
        wide_seen[w.value] = 1'b1;
        if (i == 0) begin
          w.impossible = 1;
          if (w.randomize()) $fatal(1, "unsatisfiable wide randc succeeded");
          w.impossible = 0;
        end
      end
      if (wide_seen !== 8'b0010_1010)
        $fatal(1, "constrained wide randc missed a legal value");
    end
    gw.srandom(32'h1020_3041); gw.child.srandom(32'h1020_3042);
    graph_wide_seen = 0;
    for (int i = 0; i <= 100; i++) begin
      if (i == 50) begin
        before_graph_wide = gw.value;
        before_graph_child = gw.child.value;
        gw.impossible = 1;
        if (gw.randomize() || gw.value != before_graph_wide
            || gw.child.value != before_graph_child)
          $fatal(1, "unsatisfiable graph-coupled wide randc changed values");
        gw.impossible = 0;
      end
      if (!gw.randomize()) $fatal(1, "graph-coupled wide randc failed");
      if (gw.value != gw.child.value || !(gw.value inside {[0:100]}))
        $fatal(1, "graph-coupled wide randc violated its constraints");
      if (graph_wide_seen[gw.value])
        $fatal(1, "graph-coupled wide randc repeated before completing its cycle");
      graph_wide_seen[gw.value] = 1'b1;
    end
    if (graph_wide_seen !== {101{1'b1}})
      $fatal(1, "graph-coupled wide randc missed a legal value");
    if (!gw.randomize() || gw.value != gw.child.value
        || !(gw.value inside {[0:100]}) || !graph_wide_seen[gw.value])
      $fatal(1, "graph-coupled wide randc did not reset after exhaustion");
    p.srandom(32'h1020_3043); p.child.srandom(32'h1020_3044);
    for (int i = 0; i <= 64; i++) begin
      if (i == 32) begin
        before_parent_graph_value = p.child.value;
        before_parent_value = p.parent_value;
        p.impossible = 1;
        if (p.randomize() || p.child.value != before_parent_graph_value
            || p.parent_value != before_parent_value)
          $fatal(1, "parent-only randc constraint failure changed graph values");
        p.impossible = 0;
      end
      if (!p.randomize())
        $fatal(1, "parent-only graph-coupled wide randc failed at %0d", i);
      if (p.child.value > 64 || p.parent_value != p.child.value
          || parent_graph_wide_seen[p.child.value])
        $fatal(1, "parent-only wide randc repeated or violated its constraint");
      parent_graph_wide_seen[p.child.value] = 1'b1;
    end
    if (parent_graph_wide_seen !== {65{1'b1}})
      $fatal(1, "parent-only graph-coupled wide randc missed a legal value");
    if (!p.randomize() || p.child.value > 64
        || p.parent_value != p.child.value
        || !parent_graph_wide_seen[p.child.value])
      $fatal(1, "parent-only graph-coupled wide randc did not reset");
    $display("PASSED");
  end
endmodule
