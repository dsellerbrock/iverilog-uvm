// IEEE 1800-2023 7.12 / 18.5.7.2: `item' is the default iterator of an
// array method with-clause, local to that expression, so it hides a
// visible class named `item'. `item::' still names the class.
class item;
  static int K = 5;
  int v;
  rand bit signed [3:0] a[2];
  constraint values { a[0] == -1; a[1] == -2; }
  constraint total { a.sum() with (int'(item)) == -3; }
endclass

class box #(int N = 1);
  static int K = N;
endclass

module issue2973_item_iterator_shadow;
  int d[3] = '{1, 2, 3};
  item q[$];
  int idx[$];
  int ok = 1;

  task automatic check(bit cond, string what);
    if (!cond) begin
      $display("FAILED: %s", what);
      ok = 0;
    end
  endtask

  initial begin
    item o;
    o = new;
    check(o.randomize(), "signed int-cast sum constraint solves");
    check(o.a[0] == -1 && o.a[1] == -2, "constrained values");
    check(d.sum() with (item * 2) == 12, "procedural sum uses the iterator");
    check(d.sum(x) with (x + item::K) == 21, "item:: names the class");
    check(d.sum() with (item + box#(7)::K) == 27, "parameterized class scope");
    check(d.sum() with (int'(item > 1)) == 2, "iterator in a cast");
    for (int i = 0; i < 3; i++) begin
      item h;
      h = new;
      h.v = i;
      q.push_back(h);
    end
    idx = q.find_first_index() with (item.v == 2);
    check(idx.size() == 1 && idx[0] == 2, "find over class handles");
    if (ok) $display("PASSED");
  end
endmodule
