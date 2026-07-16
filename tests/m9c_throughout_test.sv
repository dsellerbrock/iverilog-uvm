// M9C: SVA `throughout` operator (IEEE 1800-2017 16.9.9).
// `guard throughout seq` requires the boolean `guard` to hold at EVERY
// clock tick from the start of `seq` until it completes — including the
// intermediate wait cycles of a multi-cycle ##N delay, not just the
// cycles where seq's own booleans are checked. Previously `throughout`
// was a loud sorry (dropped assertion); now it is lowered to a
// unit-delay sequence with `guard` AND-ed into every cycle.
//
// Adversarial: the drop-at-intermediate-cycle case (en low only at the
// wait cycle of `##2`) MUST fail — a naive "AND guard into the booleans
// only" lowering would wrongly pass it.
module m9c_throughout_test_top;
  logic clk = 0, en, a, b;
  int hit2 = 0;
  int errors = 0;
  always #5 clk = ~clk;

  // 2-cycle span: en must hold at c0, c1 (wait), c2. The wait cycle is
  // the discriminating case — en low only there must still fail.
  a2: assert property (@(posedge clk) en throughout (a ##2 b)) hit2++;
      else /* suppress default per-tick failure noise */ ;

  // Drive one 3-cycle window for the ##2 assertion with a chosen en
  // profile (en at c0,c1,c2). b pulses at c2, a at c0.
  task win2(logic e0, logic e1, logic e2);
    a=1; b=0; en=e0; @(posedge clk); #1;   // c0
    a=0; b=0; en=e1; @(posedge clk); #1;   // c1 (wait cycle)
    a=0; b=1; en=e2; @(posedge clk); #1;   // c2
    a=0; b=0; en=1;  @(posedge clk); #1;   // idle
  endtask

  task check(string w, int got, int exp);
    if (got !== exp) begin
      $display("FAIL: %s got=%0d exp=%0d", w, got, exp);
      errors++;
    end
  endtask

  initial begin
    a=0; b=0; en=1; @(posedge clk); #1;

    win2(1,1,1);                 // good: en holds throughout -> +1
    check("after good", hit2, 1);
    win2(1,0,1);                 // en drops at the WAIT cycle -> no hit
    check("after wait-drop", hit2, 1);
    win2(1,1,0);                 // en drops at the b cycle -> no hit
    check("after end-drop", hit2, 1);
    win2(0,1,1);                 // en low at start -> no hit
    check("after start-drop", hit2, 1);
    win2(1,1,1);                 // good again -> +1
    check("after good2", hit2, 2);

    if (errors == 0) $display("PASS: m9c throughout");
    else $display("FAIL: m9c throughout (%0d errors)", errors);
    $finish(0);
  end
endmodule
