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
module main;
  cyclic_root r = new;
  static_node s = new;
  static_struct_node t = new;
  dynamic_randc_root d = new;
  bit [3:0] seen, shared_seen, struct_seen;
  bit [1024:0] dynamic_seen;
  bit [1:0] before_parent, before_child;
  bit [10:0] before_dynamic, before_dynamic_child;
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
    $display("PASSED");
  end
endmodule
