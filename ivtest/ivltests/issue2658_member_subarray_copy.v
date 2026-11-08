// Issue #2658 (and the struct-member read of #2624): IEEE 1800-2017/2023
// 7.4 and 7.6 -- one index into a multi-dimensional unpacked array names a
// subarray, which can be copied to and from an unpacked array of equivalent
// shape, also when the array is a class property or a struct member.
// Elements pair left to right in each dimension.
module test;
  typedef struct {int m[2][3];} row_t;
  class C;
    int a[2][3];
    int a3[2][2][3];
    int r[0:1][2:0];
    row_t inner;
    function void load(int src[3]); a[0] = src; endfunction
    function void take(output int dst[3]); dst = a[0]; endfunction
  endclass
  typedef struct {int a[2][3]; row_t t;} s_t;

  C c, c2; s_t s; int b[4][3]; int d[3]; int e[2][3]; int i;
  bit failed = 0;

  task check(input int got, input int exp, input string what);
    if (got !== exp) begin
      $display("FAILED: %s = %0d, expected %0d", what, got, exp);
      failed = 1;
    end
  endtask

  initial begin
    c = new; c2 = new;
    foreach (b[p, q]) b[p][q] = p*10 + q;
    foreach (e[p, q]) e[p][q] = 100 + p*10 + q;

    // The issue: class-property and struct-member destinations, property source.
    c.a[1] = b[2];
    s.a[0] = b[3];
    d = c.a[1];
    check(c.a[1][2], 22, "c.a[1][2]");
    check(s.a[0][1], 31, "s.a[0][1]");
    check(d[0], 20, "d[0] from c.a[1]");

    // Struct-member source (#2624).
    s.a[1] = b[1];
    d = s.a[1];
    check(d[2], 12, "d[2] from s.a[1]");

    // Two remaining dimensions, both directions.
    c.a3[1] = e;
    check(c.a3[1][0][0], 100, "c.a3[1][0][0]");
    check(c.a3[1][1][2], 112, "c.a3[1][1][2]");
    check(c.a3[0][1][2], 0, "c.a3[0][1][2] untouched");
    e = '{default:0};
    e = c.a3[1];
    check(e[0][1], 101, "e[0][1]");
    check(e[1][2], 112, "e[1][2]");

    // A descending range pairs its left element with the source's left one.
    c.r[0] = b[1];
    check(c.r[0][2], 10, "c.r[0][2]");
    check(c.r[0][0], 12, "c.r[0][0]");
    d = c.r[0];
    check(d[0], 10, "d[0] from c.r[0]");
    check(d[2], 12, "d[2] from c.r[0]");

    // A run-time index, and an out-of-range one (the read yields defaults).
    i = 1; c.a3[i][0] = b[3];
    check(c.a3[1][0][2], 32, "c.a3[i][0]");
    i = 7; d = c.a3[i][0];
    check(d[0], 0, "out-of-range read d[0]");

    // Nested members, and property to property through two handles.
    c.inner.m[0] = b[1]; s.t.m[1] = c.inner.m[0];
    check(c.inner.m[0][2], 12, "c.inner.m[0][2]");
    check(s.t.m[1][0], 10, "s.t.m[1][0]");
    c2.a3[0][1] = c.a3[1][0];
    check(c2.a3[0][1][2], 32, "c2.a3[0][1][2]");

    // Implicit this inside methods.
    d = '{4, 5, 6};
    c.load(d); d = '{default:0}; c.take(d);
    check(c.a[0][2], 6, "load");
    check(d[0], 4, "take");

    if (!failed) $display("PASSED");
  end
endmodule
