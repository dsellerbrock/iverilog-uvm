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
module main;
  cyclic_root r = new;
  static_node s = new;
  static_struct_node t = new;
  bit [3:0] seen, shared_seen, struct_seen;
  bit [1:0] before_parent, before_child;
  string child_state, struct_child_state;
  initial begin
    s.child = new; t.child = new;
    r.srandom(23); r.child.srandom(31);
    s.srandom(23); s.child.srandom(31);
    t.srandom(23); t.child.srandom(31);
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
    $display("PASSED");
  end
endmodule
