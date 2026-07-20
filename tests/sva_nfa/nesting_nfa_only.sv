// M9-NFA stage B.3: recursive combinator nesting — flat N-way, mixed
// precedence (and/intersect tighter than or), and parenthesized
// regrouping. Legacy sorries on all; the automaton engine lowers the
// full tree. Counts are displayed into the verdict stream and checked
// against the gold. Each cover attempt that matches counts once.
module nesting_nfa_only;
  logic clk = 0, a=0,b=0,c=0,d=0,e=0,f=0;
  always #5 clk = ~clk;

  // 3-way or: matches if ANY of the three 2-cycle chains completes.
  n1: cover property (@(posedge clk) (a ##1 b) or (c ##1 d) or (e ##1 f));
  // precedence: `and' binds tighter -> a or ((c##1d) and (e##1f))
  n2: cover property (@(posedge clk) a or (c ##1 d) and (e ##1 f));
  // paren regroup: ((a##1b) or (c##1d)) and (e##1f)
  n3: cover property (@(posedge clk) ((a ##1 b) or (c ##1 d)) and (e ##1 f));

  initial begin
    // Phase A @15: only e rises; @25 f rises. (e##1f) completes @25.
    @(negedge clk) e=1;
    @(negedge clk) e=0; f=1;   // n1: 3rd branch -> +1. n2: (c##1d) dead (c=0), a=0 -> 0. n3: left dead, right ok but AND needs left -> 0
    @(negedge clk) f=0;
    @(negedge clk);
    // Phase B @45: a,c,e rise; @55 b,d,f rise. all chains complete @55.
    @(negedge clk) a=1; c=1; e=1;
    @(negedge clk) a=0; c=0; e=0; b=1; d=1; f=1;  // n1:+1 ; n2: (c##1d)and(e##1f) both @55 ->+1 ; n3: (left or)&&right ->+1
    @(negedge clk) b=0; d=0; f=0;
    @(negedge clk);
    // Phase C @75: only a rises (n2 bare `a' alternative); @85 b rises.
    @(negedge clk) a=1;
    @(negedge clk) a=0; b=1;   // n1: (a##1b) 1st branch ->+1 ; n2: bare `a' matched @75 ->+1 ; n3: left(a##1b) ok but right(e##1f) dead -> 0
    @(negedge clk) b=0;
    @(negedge clk);
    $display("n1=%0d n2=%0d n3=%0d", _ivl_sva0_cnt0, _ivl_sva1_cnt0, _ivl_sva2_cnt0);
    $finish(0);
  end
endmodule
