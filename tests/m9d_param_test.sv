// M9D: parameterized SVA sequences and properties (IEEE 1800-2017
// 16.8/16.12). A named sequence/property may take formal arguments that
// are substituted with the actual argument expressions at each
// instantiation. Previously these declarations were parsed-and-dropped
// (the reference silently failed); now the body is cloned with the
// formals substituted and fed through the assertion engine.
//
// Discriminators: sab(x,y) and sab(y,x) instantiate the SAME sequence
// with swapped arguments and must produce DIFFERENT match sets, proving
// the substitution is per-instantiation.
module m9d_param_test_top;
  logic clk = 0, x, y;
  int hit = 0, hit2 = 0, ferr = 0, pfail = 0;
  int errors = 0;
  always #5 clk = ~clk;

  // Parameterized sequence: a then b on the next cycle.
  sequence sab(a, b);
    a ##1 b;
  endsequence

  // Parameterized property: a implies b (overlapping), clock supplied at
  // the assertion site.
  property pab(a, b);
    a |-> b;
  endproperty

  sp:  assert property (@(posedge clk) sab(x, y)) hit++;  else ferr++;
  sp2: assert property (@(posedge clk) sab(y, x)) hit2++; else ferr++;
  pp:  assert property (@(posedge clk) pab(x, y)) else pfail++;

  // Profile: x = 1 1 0 0 ; y = 0 0 1 1 (idx 0..3).
  //  sab(x,y)=x##1y matches once (x@idx1 && y@idx2).
  //  sab(y,x)=y##1x never matches.
  //  pab(x,y)=x|->y fails twice (idx0, idx1: x high, y low).
  localparam int N = 4;
  bit [0:N-1] xv = 4'b1100;
  bit [0:N-1] yv = 4'b0011;

  task check(string w, int got, int exp);
    if (got !== exp) begin
      $display("FAIL: %s got=%0d exp=%0d", w, got, exp);
      errors++;
    end
  endtask

  initial begin
    x=0; y=0; @(posedge clk); #1;
    x=0; y=0; @(posedge clk); #1;
    for (int i = 0; i < N; i++) begin
      x = xv[i]; y = yv[i];
      @(posedge clk); #1;
    end
    x=0; y=0; @(posedge clk); #1;
    x=0; y=0; @(posedge clk); #1;

    check("sab(x,y) hits", hit,  1);
    check("sab(y,x) hits", hit2, 0);
    check("pab(x,y) fails", pfail, 2);

    if (errors == 0) $display("PASS: m9d parameterized sequences/properties");
    else $display("FAIL: m9d param (%0d errors)", errors);
    $finish(0);
  end
endmodule
