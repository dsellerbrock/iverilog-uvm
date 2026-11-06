// IEEE 1800-2017/2023 7.6: a subarray with more than one remaining
// dimension is an unpacked array; copies map elements left to left in
// every dimension. 7.4.6 / Table 7-1: reading through an invalid index
// yields the element type's default, and writing through one does nothing.
module issue428_uarray_multidim_prefix;
  int a[2][2][3];
  int b[4][2][3];
  int c[2][3];
  int m[0:1][2:0];          // second dimension runs the other way
  int s[3][2][2];
  int i = 1, j = 2, bad = 9;
  bit ok = 1;

  task check(bit c, string what);
    if (!c) begin $display("FAILED: %s", what); ok = 0; end
  endtask

  initial begin
    foreach (b[p,q,r]) b[p][q][r] = p*100 + q*10 + r;
    foreach (c[q,r]) c[q][r] = 50 + q*10 + r;

    a[0] = b[2];
    check(a[0][1][2] == 212 && a[0][0][0] == 200, "constant prefix copy");
    a[i] = b[j+1];
    check(a[1][0][1] == 301 && a[1][1][2] == 312, "run-time prefix copy");
    c = b[1];
    check(c[0][0] == 100 && c[1][2] == 112, "prefix source to whole destination");
    a[0] = c;
    check(a[0][1][0] == 110, "whole source to prefix destination");

    m = c;
    check(m[0][2] == 100 && m[0][0] == 102 && m[1][2] == 110,
          "opposite direction maps left to left");
    a[1] = m;
    check(a[1][0][0] == 100 && a[1][0][2] == 102, "opposite direction back");

    a[0] = b[bad];
    check(a[0][0][0] == 0 && a[0][1][2] == 0, "invalid source prefix reads defaults");
    a[0] = c;
    b[bad] = a[0];
    check(b[3][1][2] == 312, "invalid destination prefix writes nothing");

    foreach (s[p,q,r]) s[p][q][r] = p*100 + q*10 + r;
    s[1] = s[0]; s[0] = s[2];
    check(s[1][1][1] == 11 && s[0][1][0] == 210, "self copy");

    a[1] <= b[0];
    c <= b[3];
    check(a[1][0][0] == 100, "nonblocking copy is deferred");
    #1;
    check(a[1][1][2] == 12 && c[1][1] == 311, "nonblocking copy");

    if (ok) $display("PASSED");
  end
endmodule
