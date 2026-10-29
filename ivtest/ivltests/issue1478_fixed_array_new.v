module issue1478_simple_fixed;
  int array[0:1];
  initial array = new[2];
endmodule

module issue1478_fixed_outer_dynamic_inner;
  int array[1][2][];
  initial array = new[4];
endmodule
