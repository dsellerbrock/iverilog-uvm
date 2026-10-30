checker issue1550_checker(logic a, logic b); endchecker
module issue1550_checker_missing_actual;
  logic a;
  issue1550_checker missing_b(a);
endmodule
