// Dynamic arrays and queues compare element-wise with == != === !== (IEEE
// 1800-2017/2023 11.4.5): equal sizes and equal elements. Icarus compared
// "handle is non-null" flags, so a == b held for any two non-empty arrays.
module test;
  bit [7:0] a[] = '{1, 2}, b[] = '{1, 3}, a2[] = '{1, 2}, c[] = '{1}, e1[], e2[];
  bit [7:0] q1[$] = {1, 2}, q2[$] = {1, 3}, q3[$] = {1, 2};
  logic [3:0] x1[] = '{4'b1x00, 4'b0001}, x2[] = '{4'b1x00, 4'b0001};
  logic [3:0] x3[] = '{4'b1100, 4'b0001}, x4[] = '{4'b1x00, 4'b0011};
  string s1[] = '{"a", "b"}, s2[] = '{"a", "c"}, s3[] = '{"a", "b"};
  real r1[$] = {1.5}, r2[$] = {1.5}, r3[$] = {2.5};
  int n1[][], n2[][];
  bit ok = 1;
  int loops = 0;
  task check(bit cond, string what);
    if (!cond) begin $display("FAILED: %s", what); ok = 0; end
  endtask
  initial begin
    n1 = new[2]; n2 = new[2];
    n1[0] = '{1, 2}; n2[0] = '{1, 2}; n1[1] = '{3}; n2[1] = '{4};
    check((a == b) === 1'b0 && (a != b) === 1'b1, "darray differ");
    check((a == a2) === 1'b1 && (a != a2) === 1'b0, "darray same");
    check((a == c) === 1'b0, "darray size");
    check((e1 == e2) === 1'b1, "empty");
    check((q1 == q2) === 1'b0 && (q1 == q3) === 1'b1, "queue");
    check((x1 == x2) === 1'bx && (x1 === x2) === 1'b1, "4-state same x");
    check((x1 == x3) === 1'bx && (x1 === x3) === 1'b0 && (x1 !== x3) === 1'b1, "4-state x vs known");
    check((x1 == x4) === 1'b0, "4-state definite difference");
    check((s1 == s2) === 1'b0 && (s1 == s3) === 1'b1, "string");
    check((r1 == r2) === 1'b1 && (r1 == r3) === 1'b0, "real");
    check((n1 == n2) === 1'b0, "nested");
    n2[1] = '{3};
    check((n1 == n2) === 1'b1, "nested equal");
    if (a == b) check(0, "if");
    check(((a == b) ? 1 : 2) == 2, "conditional operator");
    while (q1 != q2 && loops < 3) loops++;
    check(loops == 3, "while");
    if (ok) $display("PASSED");
  end
endmodule
