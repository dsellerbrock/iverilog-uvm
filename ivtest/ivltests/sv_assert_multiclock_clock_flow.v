// M9-7: IEEE 1800-2017 16.13 clock-flow boundaries and 16.5.1
// Preponed sampling. A ##0 boundary may consume a coincident second-clock
// tick; ##1 must wait for the first strictly subsequent tick. Operands in
// both domains still use the values from the Preponed region, even when a
// blocking write precedes both clock edges in the same Active-region process.
module main;
  reg c1 = 0, c2 = 0;
  reg a = 0, b = 0;
  reg pc1 = 0, pc2 = 0, px = 0;

  int overlap_pass = 0, overlap_fail = 0;
  int strict_pass = 0, strict_fail = 0;
  int prefix_pass = 0, prefix_fail = 0;
  int direct_pass = 0, direct_fail = 0;
  int param_pass = 0, param_fail = 0;
  int named_seq_pass = 0, named_seq_fail = 0;

  // b changes from 0 to 1 in the same time slot as the first coincident
  // c1/c2 edge. The ##0 suffix must consume that c2 edge but see sampled
  // b==0, then see b==1 on the second coincident edge.
  ov: assert property (@(posedge c1) 1'b1 ##0 @(posedge c2) b)
        overlap_pass++;
      else
        overlap_fail++;

  // The coincident c2 edge is not strictly after c1. The first attempt is
  // therefore judged at the next c2 edge; a second attempt launched there
  // remains pending until the c2-only edge at t=30.
  no: assert property (@(posedge c1) 1'b1 ##1 @(posedge c2) b)
        strict_pass++;
      else
        strict_fail++;

  // The first-clock prefix is sampled too. At t=10, a is 0 in Preponed
  // despite the preceding blocking assignment, so this fails before the
  // boundary. At t=20 it reaches the coincident c2 edge and passes.
  pr: assert property (@(posedge c1) a ##0 @(posedge c2) 1'b1)
        prefix_pass++;
      else
        prefix_fail++;

  // The direct overlapping-implication spelling has the same at-or-after
  // boundary as ##0. This was formerly a deliberate negative test.
  di: assert property (@(posedge c1) 1'b1 |-> @(posedge c2) b)
        direct_pass++;
      else
        direct_fail++;

  // A parameterized property may carry the second clock in its body while
  // the assertion supplies the first clock. The clock formal must be
  // substituted, and the prefix/boundary must survive instantiation.
  property param_flow(ck, x);
    1'b1 ##0 @(posedge ck) x;
  endproperty
  pi: assert property (@(posedge pc1) param_flow(pc2, px))
        param_pass++;
      else
        param_fail++;

  // A named sequence call in the second-clock suffix is spliced there; it
  // must not make whole-property expansion discard the clock boundary.
  sequence suffix(v);
    v ##1 1'b1;
  endsequence
  ns: assert property (@(posedge pc1) 1'b1 ##0 @(posedge pc2) suffix(px))
        named_seq_pass++;
      else
        named_seq_fail++;

  initial begin
    // pc1@12 samples px==0. px rises before pc2@17, so a correctly
    // preserved two-clock property passes there. If instantiation strips
    // the boundary and evaluates the suffix on pc1, this first attempt
    // fails. The second pc1/pc2 pair is a passing control.
    #12 pc1 = 1;
    #1 pc1 = 0;
    #1 px = 1;
    #3 pc2 = 1;
    #1 pc2 = 0;
    #4 pc1 = 1;
    #1 pc1 = 0;
    #4 pc2 = 1;
    #1 pc2 = 0;
    #9 pc2 = 1;
    #1 pc2 = 0;
  end

  initial begin
    #10;
    a = 1;
    b = 1;
    c1 = 1;
    c2 = 1;
    #1;
    c1 = 0;
    c2 = 0;

    #9;
    c1 = 1;
    c2 = 1;
    #1;
    c1 = 0;
    c2 = 0;

    #9;
    c2 = 1;
    #1;
    c2 = 0;

    #14;
    if (overlap_pass != 1 || overlap_fail != 1)
      $display("FAILED -- ##0 suffix pass/fail=%0d/%0d, expected 1/1; the coincident suffix did not use its Preponed sample",
               overlap_pass, overlap_fail);
    else if (strict_pass != 2 || strict_fail != 0)
      $display("FAILED -- ##1 suffix pass/fail=%0d/%0d, expected 2/0; a coincident c2 tick was consumed or an obligation was lost",
               strict_pass, strict_fail);
    else if (prefix_pass != 1 || prefix_fail != 1)
      $display("FAILED -- first-clock prefix pass/fail=%0d/%0d, expected 1/1; the prefix did not use its Preponed sample",
               prefix_pass, prefix_fail);
    else if (direct_pass != 1 || direct_fail != 1)
      $display("FAILED -- direct |-> pass/fail=%0d/%0d, expected 1/1; its at-or-after boundary differs from ##0",
               direct_pass, direct_fail);
    else if (param_pass != 2 || param_fail != 0)
      $display("FAILED -- parameterized clock-flow property pass/fail=%0d/%0d, expected 2/0; instantiation lost its prefix, event, or boundary",
               param_pass, param_fail);
    else if (named_seq_pass != 2 || named_seq_fail != 0)
      $display("FAILED -- named second-clock sequence pass/fail=%0d/%0d, expected 2/0; the suffix was not spliced after the boundary",
               named_seq_pass, named_seq_fail);
    else
      $display("PASSED");
    $finish(0);
  end
endmodule
