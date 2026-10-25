// M9-7: a sampled-value function in the second-clock suffix uses that
// domain's history. Its sampler must tick on every c2 edge, including edges
// where no cross-clock obligation is due.
module main;
  reg c1 = 0, c2 = 0;
  reg a = 1, b = 0;
  int passes = 0, fails = 0;
  int prefix_passes = 0, prefix_fails = 0;
  int rose_passes = 0, rose_fails = 0;
  int fell_passes = 0, fell_fails = 0;
  int stable_passes = 0, stable_fails = 0;
  int changed_passes = 0, changed_fails = 0;

  // c2@5 samples b==0. The c1/c2 edge at t=10 must therefore see
  // $past(b)==0 and fail, even though b itself has been 1 since t=6.
  // c2@15 samples b==1, so the second attempt at t=20 passes.
  p: assert property (@(posedge c1)
       1'b1 ##0 @(posedge c2) $past(b))
       passes++;
     else
       fails++;

  // The same binding applies in the first-clock prefix.
  pp: assert property (@(posedge c1)
        $past(a) ##0 @(posedge c2) 1'b1)
        prefix_passes++;
      else
        prefix_fails++;

  pr: assert property (@(posedge c1)
        1'b1 ##0 @(posedge c2) $rose(b))
        rose_passes++;
      else
        rose_fails++;
  pf: assert property (@(posedge c1)
        1'b1 ##0 @(posedge c2) $fell(b))
        fell_passes++;
      else
        fell_fails++;
  ps: assert property (@(posedge c1)
        1'b1 ##0 @(posedge c2) $stable(b))
        stable_passes++;
      else
        stable_fails++;
  pc: assert property (@(posedge c1)
        1'b1 ##0 @(posedge c2) $changed(b))
        changed_passes++;
      else
        changed_fails++;

  initial begin
    #5 c2 = 1;
    #1 begin
      c2 = 0;
      b = 1;
    end
    #4 begin
      c1 = 1;
      c2 = 1;
    end
    #1 begin
      c1 = 0;
      c2 = 0;
    end
    #4 c2 = 1;
    #1 begin
      c2 = 0;
      b = 0;
    end
    #4 begin
      c1 = 1;
      c2 = 1;
    end
    #1 begin
      c1 = 0;
      c2 = 0;
    end
    #4 c2 = 1;
    #1 c2 = 0;
    #4 begin
      c1 = 1;
      c2 = 1;
    end
    #1 begin
      c1 = 0;
      c2 = 0;
    end
    #4;

    if (passes != 1 || fails != 2)
      $display("FAILED -- c2 $past pass/fail=%0d/%0d, expected 1/2; history did not advance on the second clock",
               passes, fails);
    else if (prefix_passes != 2 || prefix_fails != 1)
      $display("FAILED -- c1 $past pass/fail=%0d/%0d, expected 2/1; prefix history used the wrong domain",
               prefix_passes, prefix_fails);
    else if (rose_passes != 1 || rose_fails != 2)
      $display("FAILED -- c2 $rose pass/fail=%0d/%0d, expected 1/2",
               rose_passes, rose_fails);
    else if (fell_passes != 1 || fell_fails != 2)
      $display("FAILED -- c2 $fell pass/fail=%0d/%0d, expected 1/2",
               fell_passes, fell_fails);
    else if (stable_passes != 1 || stable_fails != 2)
      $display("FAILED -- c2 $stable pass/fail=%0d/%0d, expected 1/2",
               stable_passes, stable_fails);
    else if (changed_passes != 2 || changed_fails != 1)
      $display("FAILED -- c2 $changed pass/fail=%0d/%0d, expected 2/1",
               changed_passes, changed_fails);
    else
      $display("PASSED");
    $finish(0);
  end
endmodule
