// Exercise both the fixed pipeline and the automaton checker.
module sva_step_cover_not;
  bit clk = 0, a = 0, b = 0, c = 0;
  int cover_matches, not_passes, not_failures;
  always #5 clk = ~clk;

  cov: cover property (@(posedge clk) a ##1 b) cover_matches++;
  neg: assert property (@(posedge clk) not (a ##1 b))
    not_passes++; else not_failures++;
  cov_nfa: cover property (@(posedge clk) a ##1 b[*1:2] ##1 c);
  neg_nfa: assert property (@(posedge clk) not (a ##1 b[*1:2] ##1 c)) else ;
  imp_nfa: cover property (@(posedge clk) a |=> b[*1:2] ##1 c);

  initial begin
    #1 $step_setup;
    a = 1;
    #10 a = 0; b = 1;
    #10 a = 1; b = 0; c = 1;
    #10 a = 0; c = 0;
    #10;
    if (cover_matches != 1 || not_passes != 3 || not_failures != 1)
      $fatal(1, "Unexpected cover or negation verdicts");
    $finish(0);
  end
endmodule
