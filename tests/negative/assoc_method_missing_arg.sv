// M1B-3 audit finding C: aa.first() with the mandatory ref index
// argument omitted silently returned 0 -- a false "empty array" answer
// on a populated array. 7.9.4 requires the argument.
module t;
  int aa[string];
  int r;
  initial begin aa["x"] = 1; r = aa.first(); end
endmodule
