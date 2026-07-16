// M13: pin the "rare but working" constructs that the milestone audit
// found already correct, so they stay correct. Covers net-type variety
// and drive strengths (tri0/tri1/wand/wor/uwire, resolved strengths),
// preprocessor stringize/paste/nested-macro expansion, and constant
// user-function evaluation in localparams ($clog2 and a hand-written
// clog2). Runs under the default harness flags (no -gspecify needed).
`define STR(x) `"x`"
`define CAT(a,b) a``b
`define BASE 41
`define INC(x) ((x)+1)

module m13_rare_constructs_test_top;
  // --- net types and drive strengths ---
  tri0 t0;             // pulls to 0 when undriven
  tri1 t1;             // pulls to 1 when undriven
  wand  wa;            // wired-AND
  wor   wo;            // wired-OR
  uwire uw;            // unresolved single-driver
  assign (weak1, weak0)   wa = 1'b1;
  assign (strong1, strong0) wa = 1'b0;   // strong 0 wins over weak 1 -> 0
  assign wo = 1'b0;
  assign wo = 1'b1;                       // wired-OR -> 1
  assign uw = 1'b1;

  // --- preprocessor: paste, stringize, nested expansion ---
  int `CAT(va, l) = `INC(`BASE);          // val == 42

  // --- constant user function in a localparam ---
  function automatic int clog2x(int v);
    int r = 0;
    while ((1 << r) < v) r++;
    return r;
  endfunction
  localparam int W  = clog2x(300);        // 9
  localparam int CC = $clog2(300);        // 9
  logic [W-1:0] bus;

  int errors = 0;
  task check(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL: %s got=%0d expected=%0d", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    #1;
    check("tri0 undriven", t0, 0);
    check("tri1 undriven", t1, 1);
    check("wand strong0 wins", wa, 0);
    check("wor", wo, 1);
    check("uwire", uw, 1);
    check("macro paste+nested", val, 42);
    if (`STR(hello) != "hello") begin
      $display("FAIL: stringize got=%s", `STR(hello));
      errors++;
    end
    check("clog2x localparam", W, 9);
    check("$clog2 localparam", CC, 9);
    check("$bits of derived width", $bits(bus), 9);
    if (errors == 0) $display("PASS: m13 rare constructs");
    else $display("FAIL: m13 rare constructs (%0d errors)", errors);
    $finish(0);
  end
endmodule
