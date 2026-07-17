// M9B: SVA `intersect` operator (IEEE 1800-2017 16.9.6).
// `s1 intersect s2` matches over an interval iff BOTH s1 and s2 match
// over exactly that interval (same start AND same end). For fixed-length
// operands of equal length this lowers to a per-cycle AND chain:
//   (a ##1 b) intersect (c ##1 d)  ==  (a&&c) ##1 (b&&d)
// Previously `intersect` was a loud sorry (dropped assertion).
//
// Discriminator: a window where s1 matches but s2 does NOT must produce
// no intersect match — a naive "just check s1" lowering would wrongly hit.
module m9b_intersect_test_top;
  logic clk = 0, a, b, c, d;
  int hit1 = 0;   // length-1 intersect matches
  int hit2 = 0;   // length-2 intersect matches
  int ferr = 0;   // per-cycle non-matches (expected under "match every
                  // cycle" semantics; collected here to keep output quiet)
  int errors = 0;
  always #5 clk = ~clk;

  // Length-1: (a ##1 b) intersect (c ##1 d) == (a&&c) ##1 (b&&d).
  p1: assert property (@(posedge clk) (a ##1 b) intersect (c ##1 d)) hit1++;
      else ferr++;
  // Length-2 (exercises the gap cycle): (a ##2 b) intersect (c ##2 d).
  p2: assert property (@(posedge clk) (a ##2 b) intersect (c ##2 d)) hit2++;
      else ferr++;

  task nap;
    begin a=0; b=0; c=0; d=0; @(posedge clk); #1; end
  endtask

  // Drive a 2-cycle window for p1: cyc0 sets (a,c), cyc1 sets (b,d).
  task win1(logic va, logic vc, logic vb, logic vd);
    begin
      a=va; c=vc; b=0;  d=0;  @(posedge clk); #1;   // cyc0
      a=0;  c=0;  b=vb; d=vd; @(posedge clk); #1;   // cyc1
    end
  endtask

  task check(string w, int got, int exp);
    if (got !== exp) begin
      $display("FAIL: %s got=%0d exp=%0d", w, got, exp);
      errors++;
    end
  endtask

  initial begin
    a=0; b=0; c=0; d=0;
    nap; nap;

    win1(1,1,1,1); nap; nap;   // both match      -> hit1+1
    check("after both-match", hit1, 1);
    win1(1,1,1,0); nap; nap;   // s1 matches, s2 d=0 -> NO hit
    check("after s2-d-fail", hit1, 1);
    win1(1,0,1,1); nap; nap;   // s2 c=0 at cyc0    -> NO hit
    check("after s2-c-fail", hit1, 1);
    win1(1,1,1,1); nap; nap;   // both match again  -> hit1+1
    check("after both-match2", hit1, 2);

    // Length-2 window: cyc0 (a,c), cyc1 gap, cyc2 (b,d).
    a=1; c=1; b=0; d=0; @(posedge clk); #1;   // cyc0
    a=0; c=0; b=0; d=0; @(posedge clk); #1;   // cyc1 (gap)
    a=0; c=0; b=1; d=1; @(posedge clk); #1;   // cyc2  -> hit2+1
    nap; nap;
    check("len2 both-match", hit2, 1);
    a=1; c=0; b=0; d=0; @(posedge clk); #1;   // cyc0 c=0
    a=0; c=0; b=0; d=0; @(posedge clk); #1;   // gap
    a=0; c=0; b=1; d=1; @(posedge clk); #1;   // cyc2  -> NO hit (c=0)
    nap; nap;
    check("len2 s2-c-fail", hit2, 1);

    if (errors == 0) $display("PASS: m9b intersect");
    else $display("FAIL: m9b intersect (%0d errors)", errors);
    $finish(0);
  end
endmodule
