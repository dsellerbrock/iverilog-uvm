// IEEE 1800-2017 A.2.10 makes `( property_expr )' a property_expr, so a
// parenthesized property is a legal implication consequent. This fork's
// sva_property_t holds the consequent in a flat step chain and cannot
// represent `throughout'/`within'/nested-implication structure there, so
// each of these assertions is refused BY NAME -- one `sorry', dropped.
//
// What this test pins is the SECOND-ORDER behaviour. Before the shape
// had any parse at all it died as a bare `syntax error' and the parser
// desynchronized: inside the generate wrapper that an assertion macro
// expands to, the recovery point lands past the block's own `end', so
// the NEXT module item is misparsed too. The gold file therefore holds
// exactly three `sorry' lines and says nothing at all about the
// perfectly ordinary code below them -- no spurious "syntax error" on a
// bare `end', no "Invalid module item" on a correct wire declaration.
//
// The two nested shapes are verbatim from OpenTitan, macro wrapper and
// all:
//   prim_sync_reqack.sv:395  `$fell(rst) |-> (!a throughout !b[->1])'
//   otbn.sv:1328             `$rose(w) |-> ((s1) within (s2))'
// The second one alone accounted for 30 of otbn's 43 diagnostics, every
// one of them attributed to unrelated, correct code further down.
module sva_paren_prop_conseq_ce;

  reg clk = 0;
  reg a = 0, b = 0, c = 0, d = 0;

  always #5 clk = ~clk;

  // prim_sync_reqack shape: `throughout' as a parenthesized consequent.
  if (1) begin : g_reqack
    ap_throughout: assert property (@(posedge clk)
                     $fell(a) |-> (!b throughout !c[->1]))
      else begin
        $error("%0t: reqack", $time);
      end
  end

  // otbn.sv:1328 shape: `within' as a parenthesized consequent, one per
  // generated register.
  if (1) begin : g_wipe
    for (genvar i = 0; i < 2; i++) begin : g_regs
      ap_within: assert property (@(posedge clk)
                   $rose(a) |-> ((b ##[0:$] c) within (a ##[0:$] d)))
        else begin
          $error("%0t: wipe %0d", $time, i);
        end
    end
  end

  // A nested implication -- also a property, also refused by name.
  ap_nested: assert property (@(posedge clk) a |-> (b |-> c));

  // Everything below here is ordinary, legal code that MUST NOT produce
  // a diagnostic. It is the whole point of the test.
  wire e = a & b;

  always @(posedge clk) d <= e;

  // A parenthesized consequent holding only a sequence is pure grouping:
  // it splices into an ordinary implication and compiles.
  ap_ok: assert property (@(posedge clk) a |-> (b ##1 c));

  initial begin
    #100;
    $display("FAILED -- should not have compiled");
    $finish;
  end

endmodule
