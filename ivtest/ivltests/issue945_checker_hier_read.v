checker issue945_check(logic s);
  bit a;
endchecker

module issue945_checker_hier_read;
  issue945_check my_check(1'b0);
  wire x = my_check.a;
endmodule
