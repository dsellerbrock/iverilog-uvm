// M1B-3 audit finding B: a well-typed unpacked aggregate assigned to a
// scalar target was silently substituted with const-0 (R30's sibling).
module t;
  int q[$];
  int i;
  initial begin q.push_back(7); i = q; end
endmodule
