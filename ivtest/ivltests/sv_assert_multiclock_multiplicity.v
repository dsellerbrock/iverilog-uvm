// M9-7: every antecedent match of a multiclocked implication is a distinct
// obligation. If several c1 matches are outstanding at one c2 edge, that edge
// must produce one pass/fail/cover result for each obligation rather than
// collapsing the batch to a single verdict.
module main;
  reg c1 = 0, c2 = 0;
  reg a = 1;
  reg trig = 0;
  reg b_pass = 1, b_fail = 0;

  int pass_count = 0;
  int fail_count = 0;
  int unexpected_fail = 0;
  int chain_pass_count = 0;
  int chain_fail_count = 0;
  int window_pass_count = 0;
  int window_fail_count = 0;
  int implication_pass_count = 0;

  ap: assert property (@(posedge c1) a |=> @(posedge c2) b_pass)
        pass_count++;
      else
        unexpected_fail++;

  af: assert property (@(posedge c1) a |=> @(posedge c2) b_fail)
        ;
      else
        fail_count++;

  cp: cover property (@(posedge c1) a |=> @(posedge c2) b_pass);

  // The pass action also runs for each vacuous implication success. Only
  // c1@10 sees trig; c1@20 and c1@30 must each pass vacuously.
  av: assert property (@(posedge c1) trig |=> @(posedge c2) b_pass)
        implication_pass_count++;
      else
        unexpected_fail++;

  // The count must survive later consequent stages, not only the handoff.
  acp: assert property
        (@(posedge c1) a |=> @(posedge c2) 1'b1 ##1 b_pass)
        chain_pass_count++;
      else
        unexpected_fail++;

  acf: assert property
        (@(posedge c1) a |=> @(posedge c2) 1'b1 ##1 b_fail)
        ;
      else
        chain_fail_count++;

  // A bounded window may have batches at several ages on one c2 tick. A
  // successful batch and an expiring batch must each retain multiplicity.
  awp: assert property
        (@(posedge c1) a |=> @(posedge c2) 1'b1 ##[1:2] b_pass)
        window_pass_count++;
      else
        unexpected_fail++;

  awf: assert property
        (@(posedge c1) a |=> @(posedge c2) 1'b1 ##[1:2] b_fail)
        ;
      else
        window_fail_count++;

  initial begin
    // Attempts start at c1@10/20/30. The first is judged at c2@15; the
    // other two are both due at the first subsequent c2 edge, c2@35.
    #9 trig = 1;
    #1 c1 = 1; #1 begin c1 = 0; trig = 0; end
    #9  c1 = 1; #1 c1 = 0;
    #9  c1 = 1; #1 c1 = 0;
  end

  initial begin
    #15 c2 = 1; #1 c2 = 0;
    #19 c2 = 1; #1 c2 = 0;
    #9  c2 = 1; #1 c2 = 0;
    #9  c2 = 1; #1 c2 = 0;
  end

  initial begin
    #58;
    if (pass_count != 3)
      $display("FAILED -- multiclock pass actions=%0d, expected 3",
               pass_count);
    else if (fail_count != 3)
      $display("FAILED -- multiclock fail actions=%0d, expected 3",
               fail_count);
    else if (unexpected_fail != 0)
      $display("FAILED -- passing consequent produced %0d failures",
               unexpected_fail);
    else if (_ivl_sva2_cnt0 != 3)
      $display("FAILED -- multiclock cover matches=%0d, expected 3",
               _ivl_sva2_cnt0);
    else if (chain_pass_count != 3 || chain_fail_count != 3)
      $display("FAILED -- fixed-chain pass/fail=%0d/%0d, expected 3/3",
               chain_pass_count, chain_fail_count);
    else if (window_pass_count != 3 || window_fail_count != 3)
      $display("FAILED -- bounded-window pass/fail=%0d/%0d, expected 3/3",
               window_pass_count, window_fail_count);
    else if (implication_pass_count != 3)
      $display("FAILED -- implication pass actions=%0d, expected 3 (one nonvacuous and two vacuous)",
               implication_pass_count);
    else
      $display("PASSED");
    $finish(0);
  end
endmodule
