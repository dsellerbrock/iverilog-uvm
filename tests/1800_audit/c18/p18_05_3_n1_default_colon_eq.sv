module p18_05_3_n1_default_colon_eq;
  class E;
    rand bit [7:0] x;
    constraint c { x dist {[100:102] :/ 3, default := 1}; }
  endclass
  E e;
  initial begin e = new; end
endmodule
