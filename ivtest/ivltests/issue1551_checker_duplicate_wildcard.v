checker issue1551_checker(logic a);
endchecker

module issue1551_top;
  logic a;
  issue1551_checker duplicate_wildcard(.*, .*);
endmodule
