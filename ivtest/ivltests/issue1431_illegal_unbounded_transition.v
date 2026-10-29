module issue1431_illegal_unbounded_transition;
  bit [1:0] value;
  covergroup cg;
    cp: coverpoint value { illegal_bins bad = (1 => 2 [-> 1]); }
  endgroup
endmodule
