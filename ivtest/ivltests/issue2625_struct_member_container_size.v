// Issue #2625: the size of a queue or dynamic array reached through an
// unpacked struct member is state in a class constraint when the member is
// not rand (IEEE 1800-2023 18.3, 18.4): it reads as the current size.
module top;
  typedef struct { int da[]; int q[$]; } bag_t;
  typedef struct { rand int x; int keep[$]; } mixed_t;

  class state_bag;
    rand int y;
    bag_t s;
    constraint cy { y == s.da.size() * 10 + s.da[1]; }
  endclass

  class state_queue;
    rand int n;
    bag_t s;
    constraint cn { n == s.q.size() + 100; }
  endclass

  // A non-rand member of a rand struct is still state (18.4).
  class rand_struct;
    rand mixed_t m;
    rand int k;
    constraint ck { k == m.keep.size(); m.x inside {[1:3]}; }
  endclass

  state_bag b = new;
  state_queue q = new;
  rand_struct r = new;
  int failures = 0;

  initial begin
    b.s.da = '{7, 8, 9};
    if (!b.randomize() || b.y != 38) failures++;
    b.s.da = '{1, 2};
    if (!b.randomize() || b.y != 22) failures++;
    q.s.q = '{5, 6, 7, 8};
    if (!q.randomize() || q.n != 104) failures++;
    q.s.q = {};
    if (!q.randomize() || q.n != 100) failures++;
    r.m.keep = '{1, 1, 1, 1, 1};
    if (!r.randomize() || r.k != 5 || r.m.x < 1 || r.m.x > 3) failures++;
    if (failures == 0) $display("PASSED");
    else $display("FAILED: %0d", failures);
  end
endmodule
