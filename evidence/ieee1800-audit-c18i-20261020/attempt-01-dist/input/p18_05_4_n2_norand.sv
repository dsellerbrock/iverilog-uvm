module p18_05_4_n2_norand;
  class C;
    int s;
    constraint c { s dist {1 := 1, 2 := 1}; }
  endclass
  initial begin C o = new; end
endmodule
