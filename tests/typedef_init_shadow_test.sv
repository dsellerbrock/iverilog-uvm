// Regression: two related scope/parse defects found via the wildcard-import
// cluster (sv_wildcard_import2/3/4/5).
//
// 1. A module-level variable declaration using a typedef'd type WITH an
//    initializer (`word v = 8'h2a;`) failed to parse ("Invalid module
//    instantiation"): the fork parses `TYPE_IDENTIFIER name;` through the
//    no-port instantiation shape and reinterprets it as a declaration, but
//    gate_instance had no `= expr` alternative, so any initializer was a
//    syntax error. gate_instance now carries the declaration initializer
//    through lgate::decl_init into the reinterpretation.
//
// 2. A local declaration that shadows a wildcard-imported name (IEEE
//    1800-2017 26.3) was rejected or mis-bound because the lexer's
//    is-this-a-type probe pinned wildcard imports as if referenced. The
//    probe is now read-only; only genuine references pin (and a local
//    declaration AFTER such a reference is still the required error —
//    covered by ivtest sv_wildcard_import4).
package tis_pkg;
  typedef logic [1:0] word;
  parameter p1 = 1;
endpackage

module top;
  import tis_pkg::*;

  // Local declarations shadow the un-referenced wildcard candidates.
  typedef logic [7:0] word;
  parameter p1 = 3;

  // Typedef'd type with initializer at module level (the parse fix).
  word v = 8'h2a;
  word arr [0:1];

  initial begin
    bit ok = 1;
    if ($bits(v) !== 8) begin ok = 0; $display("FAIL: $bits(v)=%0d exp 8 (shadow lost)", $bits(v)); end
    if (v !== 8'h2a)   begin ok = 0; $display("FAIL: v=%h exp 2a (initializer lost)", v); end
    if (p1 !== 3)      begin ok = 0; $display("FAIL: p1=%0d exp 3 (local param shadow lost)", p1); end
    if (ok) $display("PASS: typedef initializer + wildcard-import shadowing");
    $finish;
  end
endmodule
