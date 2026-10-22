module p18_05_3_n2_two_defaults;
  class E;
    rand bit [7:0] x;
    constraint c { x dist {default :/ 1, default :/ 2}; }
  endclass
  E e;
  initial begin e = new; end
endmodule
