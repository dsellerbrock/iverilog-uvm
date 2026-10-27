module n10_09_duplicate_member_key;
  typedef struct { int a; byte b; int c; real r; } S;
  S s;
  initial s = '{a:1, a:2, b:0, c:0, r:0.0};
endmodule
