// IEEE 1800-2017 §18.5.5; IEEE 1800-2023 §18.5.4.
module p18_05_5_n1_randc;
  class C;
    randc bit [3:0] x;
    rand bit [3:0] y;
    constraint c { unique {x, y}; }
  endclass
  C o = new;
endmodule
