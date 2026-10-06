// IEEE 1800-2017 18.5.9/18.5.10; IEEE 1800-2023 18.5.8/18.5.9.
// Object replay: IEEE 1800-2017/2023 18.14.1/18.14.3.
class leaf;
  rand bit value;
endclass
class root;
  rand bit value;
  rand leaf child;
  function new(); child = new; endfunction
  constraint c { value >= child.value; }
endclass
class table18_2_unordered;
  rand bit s;
  rand bit [31:0] d;
  constraint c { s -> d == 0; }
endclass
class table18_2_ordered;
  rand bit s;
  rand bit [31:0] d;
  constraint c { s -> d == 0; }
  constraint order { solve s before d; }
endclass
class dynamic_array_unordered;
  rand bit m;
  rand bit [7:0] q[];
  constraint c { q.size() == 2; foreach (q[i]) m -> q[i] == 5; }
endclass
class dynamic_array_ordered;
  rand bit m;
  rand bit [7:0] q[];
  constraint c { q.size() == 2; foreach (q[i]) m -> q[i] == 5; }
  constraint order { solve m before q; }
endclass
module main;
  root r = new;
  root unrelated = new;
  table18_2_unordered unordered = new;
  table18_2_ordered ordered = new;
  dynamic_array_unordered dyn_unordered = new;
  dynamic_array_ordered dyn_ordered = new;
  int count[4];
  bit [1:0] replay[20];
  int unordered_s1, ordered_s1;
  int dyn_unordered_m1, dyn_ordered_m1;
  string root_state, child_state;
  int noise;
  initial begin
    r.srandom(73); r.child.srandom(73);
    unordered.srandom(73); ordered.srandom(73);
    repeat (6000) begin
      if (!r.randomize()) $fatal(1, "joint solve failed");
      count[{r.value, r.child.value}]++;
    end

    if (count[1] || count[0] < 1800 || count[0] > 2200
        || count[2] < 1800 || count[2] > 2200
        || count[3] < 1800 || count[3] > 2200)
      $fatal(1, "joint tuples are not uniform");
    root_state = r.get_randstate(); child_state = r.child.get_randstate();
    for (int i=0; i<20; ++i) begin
      if (!r.randomize()) $fatal(1, "replay setup failed");
      replay[i] = {r.value, r.child.value};
    end
    r.set_randstate(root_state); r.child.set_randstate(child_state);
    for (int i=0; i<20; ++i) begin
      noise = $urandom;
      if (!unrelated.randomize()) $fatal(1, "unrelated solve failed");
      if (!r.randomize() || {r.value, r.child.value} != replay[i])
        $fatal(1, "joint RNG replay depends on unrelated calls");
    end

    // IEEE 1800-2017 Table 18-2 and 1800-2023 Table 18-1: without solve-before,
    // only one of 2^32+1 legal tuples has s==1. Ordering s before d changes the
    // marginal to a uniform choice of s first.
    repeat (256) begin
      if (!unordered.randomize() || !ordered.randomize())
        $fatal(1, "Table 18-2 randomization failed");
      unordered_s1 += unordered.s;
      ordered_s1 += ordered.s;
    end
    if (unordered_s1 > 10)
      $fatal(1, "unordered legal tuples are biased: s==1 %0d/256", unordered_s1);
    if (ordered_s1 < 90 || ordered_s1 > 166)
      $fatal(1, "solve-before marginal is biased: s==1 %0d/256", ordered_s1);

    // A two-element array has 2^16 legal tuples when m==0, but only one
    // when m==1. The unordered result should follow complete legal tuples;
    // solve-before intentionally keeps the marginal near one half.
    dyn_unordered.srandom(79); dyn_ordered.srandom(79);
    repeat (128) begin
      if (!dyn_unordered.randomize() || !dyn_ordered.randomize())
        $fatal(1, "dynamic-array randomization failed");
      if (dyn_unordered.m && (dyn_unordered.q[0] != 5 || dyn_unordered.q[1] != 5))
        $fatal(1, "unordered dynamic-array constraint failed");
      if (dyn_ordered.m && (dyn_ordered.q[0] != 5 || dyn_ordered.q[1] != 5))
        $fatal(1, "ordered dynamic-array constraint failed");
      dyn_unordered_m1 += dyn_unordered.m;
      dyn_ordered_m1 += dyn_ordered.m;
    end
    if (dyn_unordered_m1 > 3)
      $fatal(1, "unordered dynamic-array tuples are biased: m==1 %0d/128",
             dyn_unordered_m1);
    if (dyn_ordered_m1 < 40 || dyn_ordered_m1 > 88)
      $fatal(1, "dynamic-array solve-before marginal is biased: m==1 %0d/128",
             dyn_ordered_m1);
    $display("PASSED");
  end
endmodule
