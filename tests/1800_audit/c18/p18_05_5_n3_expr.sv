// IEEE 1800-2017 §18.5.5; IEEE 1800-2023 §18.5.4.
module p18_05_5_n3_expr;
  class C;
    rand byte x, y;
    constraint c { unique {x + 1, y}; }
  endclass
  C o = new;
endmodule
