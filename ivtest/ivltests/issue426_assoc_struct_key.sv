// IEEE 1800-2017/2023 7.8.5: an associative array indexed by an unpacked
// struct uses the struct's equality operator, so equal values name one entry.
// 7.9.11/10.9.1: a literal may key such an array with typed struct patterns.
module issue426_assoc_struct_key;
  typedef struct {int x; logic [3:0] y;} us_t;
  typedef struct {us_t in; string s;} nest_t;
  int m[us_t];
  int n[nest_t];
  us_t a, b, k;
  nest_t na, nb;
  us_t q[$], r[$];
  bit ok = 1;

  task check(bit c, string what);
    if (!c) begin $display("FAILED: %s", what); ok = 0; end
  endtask

  initial begin
    a = '{1, 4'd2}; b = '{1, 4'd2};
    m[a] = 5;
    check(m.num() == 1 && m.exists(b) && m[b] == 5, "equal value finds entry");
    m[b] = 6;
    check(m.num() == 1 && m[a] == 6, "equal value overwrites entry");
    a.x = 9;   // the stored key is a copy, not the variable
    check(m.num() == 1 && m.exists(b) && !m.exists(a), "key isolated from source");
    void'(m.first(k)); k.x = 77;
    check(m.exists(b) && m.first(k) == 1 && k.x == 1, "traversal key is a copy");
    m.delete(us_t'{1, 4'd2});
    check(m.num() == 0, "delete by equal typed pattern");

    na = '{'{3, 4'd3}, "s"}; nb = '{'{3, 4'd3}, "s"};
    n[na] = 1; n[nb] += 1;
    check(n.num() == 1 && n[na] == 2, "nested struct key");
    nb.s = "t";
    check(!n.exists(nb), "nested struct key differs");

    m = '{us_t'{1, 4'd2}: 5, us_t'{3, 4'd4}: 6};
    check(m.num() == 2 && m[us_t'{1, 4'd2}] == 5 && m[us_t'{3, 4'd4}] == 6,
          "typed struct keys in a literal");

    q.push_back(a); r.push_back(us_t'{9, 4'd2});
    check(q == r, "queue == compares struct elements by value");
    r[0].y = 4'd3;
    check(q != r, "queue != compares struct elements by value");

    if (ok) $display("PASSED");
  end
endmodule
