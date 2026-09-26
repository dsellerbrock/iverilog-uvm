// Associative arrays compare with == != === !== (IEEE 1800-2017/2023
// 11.4.5): same keys, equal values. Class-handle values compare by
// identity, container values element-wise, and object keys by identity.
class c; int v; endclass
module test;
  int a1[string], a2[string];
  logic [3:0] x1[int], x2[int];
  string s1[int], s2[int];
  c o1[int], o2[int];
  int q1[int][$], q2[int][$];
  int k1[c], k2[c];
  bit ok = 1;
  task check(bit cond, string what);
    if (!cond) begin $display("FAILED: %s", what); ok = 0; end
  endtask
  initial begin
    automatic c h1 = new, h2 = new;
    a1["a"] = 1; a2["a"] = 1;
    check((a1 == a2) === 1'b1, "int same");
    a2["b"] = 2;
    check((a1 == a2) === 1'b0 && (a1 != a2) === 1'b1, "int size");
    a1["c"] = 2;
    check((a1 == a2) === 1'b0, "int key");
    x1[0] = 4'b1x00; x2[0] = 4'b1x00;
    check((x1 == x2) === 1'bx && (x1 === x2) === 1'b1, "4-state");
    s1[3] = "p"; s2[3] = "q";
    check((s1 == s2) === 1'b0, "string");
    o1[0] = h1; o2[0] = h1;
    check((o1 == o2) === 1'b1, "handle same");
    o2[0] = h2;
    check((o1 == o2) === 1'b0, "handle identity");
    q1[5] = {1, 2}; q2[5] = {1, 2};
    check((q1 == q2) === 1'b1, "queue values");
    q2[5].push_back(3);
    check((q1 == q2) === 1'b0, "queue values differ");
    k1[h1] = 1; k2[h2] = 1;
    check((k1 == k2) === 1'b0, "object keys");
    k2.delete(); k2[h1] = 1;
    check((k1 == k2) === 1'b1, "object keys same");
    if (ok) $display("PASSED");
  end
endmodule
