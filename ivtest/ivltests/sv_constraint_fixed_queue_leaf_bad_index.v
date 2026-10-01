class bad_index;
  rand bit q[2][$];
  constraint sizes { q[1'bx].size() == 1; q[2].size() == 1; }
endclass
module test; bad_index c; endmodule
