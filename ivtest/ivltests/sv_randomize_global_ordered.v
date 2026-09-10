// IEEE 1800-2017 18.5.9/18.5.10; IEEE 1800-2023 18.5.8/18.5.9.
class ordered_leaf;
  rand bit [1:0] value;
  int posts;
  function void post_randomize(); posts++; endfunction
endclass
class ordered_root;
  rand bit select;
  rand bit [1:0] data;
  rand ordered_leaf child;
  ordered_leaf alias_view;
  bit impossible;
  int posts;
  function new(); child = new; alias_view = child; endfunction
  function void post_randomize(); posts++; endfunction
  constraint c {
    solve select before data;
    select -> data == 0;
    alias_view.value == data;
    if (impossible) { select == 0; select == 1; }
  }
endclass
class latest_root;
  rand bit a, b, c, d;
  rand ordered_leaf child;
  function new(); child = new; endfunction
  constraint order_c { solve a before b; solve b, d before c; }
  constraint c_hard { b -> d == 0; child.value == c; }
endclass
class chain_root;
  rand bit a, b;
  rand bit [1:0] c;
  rand ordered_leaf child;
  function new(); child = new; endfunction
  constraint order_c { solve a before b; solve b before c; }
  constraint hard_c { a -> b == 0; b -> c == 0; child.value == c; }
endclass
class nested_ordered_root;
  rand ordered_root first, second;
  function new(); first = new; second = new; endfunction
endclass
module main;
  ordered_root r = new;
  latest_root t = new;
  chain_root chain = new;
  nested_ordered_root nested = new;
  int nested_first, nested_second;
  int chain_a, chain_b, chain_c;
  int counts[8];
  int late_d;
  bit [2:0] replay[20];
  string root_state, child_state;
  bit [2:0] old_values;
  int old_posts, old_child_posts;
  initial begin
    r.srandom(53); r.child.srandom(59); t.srandom(61);
    chain.srandom(67);
    repeat (2048) begin
      if (!chain.randomize() || (chain.a && chain.b) || (chain.b && chain.c != 0) || chain.child.value != chain.c)
        $fatal(1, "coupled three-stage chain failed");
      if (!nested.randomize() || (nested.first.select && nested.first.data != 0)
          || (nested.second.select && nested.second.data != 0)
          || nested.first.child.value != nested.first.data
          || nested.second.child.value != nested.second.data)
        $fatal(1, "child-owned ordering failed");
      nested_first += nested.first.select; nested_second += nested.second.select;
      chain_a += chain.a; chain_b += chain.b; chain_c += (chain.c != 0);
      if (!r.randomize()) $fatal(1, "ordered joint graph failed");
      if ((r.select && r.data != 0) || r.child.value != r.data)
        $fatal(1, "hard relation or alias identity lost");
      counts[{r.select,r.data}]++;
      if (!t.randomize()) $fatal(1, "partial order failed");
      if (t.b && t.d) $fatal(1, "partial-order hard relation lost");
      if (t.d) late_d++;
    end
    if (nested_first < 864 || nested_first > 1184 || nested_second < 864 || nested_second > 1184)
      $fatal(1, "child-owned ordering marginal changed");
    if (chain_a < 864 || chain_a > 1184 || chain_b < 384 || chain_b > 640
        || chain_c < 992 || chain_c > 1312)
      $fatal(1, "coupled three-stage marginals changed");
    // First-stage select is uniform; conditional data has four equal values.
    if (counts[4] < 864 || counts[4] > 1184)
      $fatal(1, "ordered marginal is not one half");
    for (int i=0; i<4; i++)
      if (counts[i] < 160 || counts[i] > 352)
        $fatal(1, "conditional fiber is not uniform");
    // d belongs with b at the latest possible stage, giving P(d)=1/3.
    // Moving d to a's stage would instead give P(d)=1/2.
    if (late_d < 546 || late_d > 820)
      $fatal(1, "partially ordered variable was sampled too early");
    if (r.posts != 2048 || r.child.posts != 2048)
      $fatal(1, "post callbacks were not exactly once per solve");

    root_state = r.get_randstate(); child_state = r.child.get_randstate();
    for (int i=0; i<20; i++) begin
      if (!r.randomize()) $fatal(1, "replay setup failed");
      replay[i] = {r.select,r.data};
    end
    r.set_randstate(root_state); r.child.set_randstate(child_state);
    for (int i=0; i<20; i++) begin
      if (!t.randomize() || !r.randomize()) $fatal(1, "replay failed");
      if ({r.select,r.data} != replay[i]) $fatal(1, "unrelated RNG changed replay");
    end
    r.select = 1;
    r.select.rand_mode(0);
    if (!r.randomize() || !r.select || r.data != 0)
      $fatal(1, "ordered frozen variable changed");
    r.select.rand_mode(1);
    old_values = {r.select,r.data};
    old_posts = r.posts; old_child_posts = r.child.posts;
    root_state = r.get_randstate(); child_state = r.child.get_randstate();
    r.impossible = 1;
    if (r.randomize()) $fatal(1, "unsatisfiable graph passed");
    if ({r.select,r.data} != old_values || r.child.value != r.data
        || r.posts != old_posts || r.child.posts != old_child_posts)
      $fatal(1, "failed ordered solve was not atomic");
    $display("PASSED");
  end
endmodule
