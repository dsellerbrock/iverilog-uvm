// IEEE 1800-2017 §18.5.5; IEEE 1800-2023 §18.5.4.
module p18_05_5_n2_type;
  class C;
    rand byte x;
    rand int y;
    constraint c { unique {x, y}; }
  endclass
  C o = new;
endmodule
