module p18_05_4_n1_randc;
  class C;
    randc bit [3:0] x;
    constraint c { x dist {1 := 1, 2 := 1}; }
  endclass
  initial begin C o = new; end
endmodule
