// M9-7: an implication may have a fixed first-clock consequent prefix
// before a ##0/##1 clock-flow boundary, followed by another fixed chain in
// the second clock domain. Prefix failures are real property failures;
// suffix failures are reported in the second domain; false antecedents are
// vacuous successes whose pass actions still execute.
module main;
  reg c1 = 0, c2 = 0;
  reg trig_ov = 0, trig_nov = 0;
  reg a = 1, x = 1, b = 1, y = 1;

  int ov_pass = 0, ov_fail = 0;
  int nov_pass = 0, nov_fail = 0;
  int prefix_fail = 0, suffix_fail = 0;
  int cover_action = 0;

  // Nonvacuous path: antecedent@10, a@10, x@30, strict boundary to
  // c2@35, b@35, y@75. c1@20/30/40 are vacuous successes.
  ov: assert property (
        @(posedge c1) trig_ov |-> a ##2 x ##1 @(posedge c2) b ##2 y)
        ov_pass++;
      else
        ov_fail++;

  // Nonvacuous path: antecedent@10, nonoverlap prefix starts at c1@20,
  // strict boundary to c2@35, and the suffix completes at c2@55.
  no: assert property (
        @(posedge c1) trig_nov |=> a ##1 @(posedge c2) b ##1 y)
        nov_pass++;
      else
        nov_fail++;

  // These discriminate the two failure sites around the boundary.
  fp: assert property (
        @(posedge c1) trig_ov |-> 1'b0 ##1 @(posedge c2) 1'b1)
        ;
      else
        prefix_fail++;
  fs: assert property (
        @(posedge c1) trig_ov |-> 1'b1 ##1 @(posedge c2) 1'b0)
        ;
      else
        suffix_fail++;

  cv: cover property (
        @(posedge c1) trig_ov |-> a ##2 x ##1 @(posedge c2) b ##2 y)
        cover_action++;

  initial begin
    #9 begin
      trig_ov = 1;
      trig_nov = 1;
    end
    #1 c1 = 1;
    #1 begin
      c1 = 0;
      trig_ov = 0;
      trig_nov = 0;
    end
    #9 c1 = 1;
    #1 c1 = 0;
    #9 c1 = 1;
    #1 c1 = 0;
    #9 c1 = 1;
    #1 c1 = 0;
  end

  initial begin
    #15 c2 = 1;
    #1 c2 = 0;
    #19 c2 = 1;
    #1 c2 = 0;
    #19 c2 = 1;
    #1 c2 = 0;
    #19 c2 = 1;
    #1 c2 = 0;
  end

  initial begin
    #78;
    if (ov_pass != 4 || ov_fail != 0)
      $display("FAILED -- overlapping fixed prefix/suffix pass/fail=%0d/%0d, expected 4/0",
               ov_pass, ov_fail);
    else if (nov_pass != 4 || nov_fail != 0)
      $display("FAILED -- nonoverlapping fixed prefix/suffix pass/fail=%0d/%0d, expected 4/0",
               nov_pass, nov_fail);
    else if (prefix_fail != 1 || suffix_fail != 1)
      $display("FAILED -- prefix/suffix failure actions=%0d/%0d, expected 1/1",
               prefix_fail, suffix_fail);
    else if (cover_action != 1)
      $display("FAILED -- nested multiclock cover action=%0d, expected 1",
               cover_action);
    else
      $display("PASSED");
    $finish(0);
  end
endmodule
