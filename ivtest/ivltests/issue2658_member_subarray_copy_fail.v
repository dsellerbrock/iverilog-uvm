// Issue #2658: a member subarray copy still requires equivalent shapes
// (IEEE 1800-2017/2023 7.6).
module test;
  class C; int a[2][3]; endclass
  C c; int b[4][4]; int d[2];
  initial begin
    c = new;
    c.a[1] = b[2];
    d = c.a[0];
  end
endmodule
