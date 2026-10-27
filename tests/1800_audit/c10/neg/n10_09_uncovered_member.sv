module n10_09_uncovered_member;
  typedef struct { int a; byte b; int c; real r; } S;
  S s;
  initial s = '{a:1, b:2};
endmodule
