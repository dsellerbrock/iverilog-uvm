// IEEE 1800-2017/2023 20.8.1: $clog2 of a constant has an elaboration-time
// value, so inside a constraint it is simply a literal.
//
// Icarus did not fold it, and a constraint ITEM that cannot be lowered is
// DROPPED. That does not merely lose an optimization -- it leaves the random
// variable completely unconstrained. Before this fix:
//
//     constraint c { v <= $clog2(64); }   // bound is 6
//     -> v came back as 2915189536
//
// reported only as "Constraint item ... is not representable in the
// constraint solver and is ignored". A wrong answer standing behind a
// compile-progress warning.
//
// OpenTitan hits it at uart_base_vseq.sv:109-110:
//     value <= $clog2(RxFifoDepth);
//     value <= $clog2(TxFifoDepth) - 1;
//
// This is an ENFORCEMENT test, not a smoke test: a fix that accepted the
// constraint without actually applying it would still let every draw
// through, so the check below draws repeatedly and fails if ANY draw lands
// outside the band. An unconstrained 32-bit value lands in [3,6] with
// probability ~1e-9, so 20 clean draws is proof the solver honours it.
//
// slang 11.0.448 accepts this file under both editions.

package pkg;
  parameter bit [127:0] WideDepth = 128'h10000000000000001;
  parameter int RxFifoDepth = 64;   // $clog2 -> 6
endpackage

class banded;
  rand int unsigned v;
  // Both bounds come from $clog2: [3,6].
  constraint c_lo { v >= $clog2(8);                 }  // 3
  constraint c_hi { v <= $clog2(pkg::RxFifoDepth);  }  // 6
endclass

class minus_one;
  rand int unsigned v;
  // The OpenTitan spelling: $clog2(P) - 1.
  constraint c { v <= $clog2(pkg::RxFifoDepth) - 1; }  // 5
endclass

class edge_values;
  rand int zero, one, nonpower, negative, signed8, signed1, signed16, wide_literal, wide_parameter, unary8, unary4, unary_plus;
  constraint c {
    zero == $clog2(0);
    one == $clog2(1);
    nonpower == $clog2(65);
    negative == $clog2(-1);
    unary8 == $clog2(-8'sd1);
    unary4 == $clog2(-4'sd8);
    unary_plus == $clog2(+8'shff);
    signed8 == $clog2(8'shff);
    signed1 == $clog2(1'sb1);
    signed16 == $clog2(16'sh8000);
    wide_literal == $clog2(128'h10000000000000000);
    wide_parameter == $clog2(pkg::WideDepth);
  }
endclass

// IEEE 1800-2017/2023 18.7.1: class constants win over caller names.
class class_parameter #(parameter int N = 8);
  rand int v;
endclass
class class_enumeration;
  typedef enum int { N = 8 } kind;
  rand int v;
endclass
module main;
  parameter int N = 64;
  // IEEE 1800-2017/2023 23.9: retain an actual hierarchical constant.
  class hierarchy;
    rand int v;
    constraint c { v == main.N; }
  endclass
  hierarchy h;
  logic signed [7:0] runtime_signed;
  class_parameter cp;
  class_parameter #(64) cp64;
  class_enumeration ce;

  int errors = 0;

  banded    b;
  minus_one m;
  edge_values e;

  initial begin
    b = new();
    m = new();
    e = new();
    if (!e.randomize() || e.zero != 0 || e.one != 0 || e.nonpower != 7
        || e.negative != 32 || e.signed8 != 8 || e.signed1 != 0 || e.signed16 != 15
        || e.wide_literal != 64 || e.wide_parameter != 65)
      $fatal(1, "clog2 constant edge values were not enforced");

    if (e.unary8 != 8 || e.unary4 != 3 || e.unary_plus != 8
        || e.unary8 != $clog2(-8'sd1) || e.unary4 != $clog2(-4'sd8)
        || e.unary_plus != $clog2(+8'shff))
      $fatal(1, "unary literal fold disagrees with ordinary evaluation");
    runtime_signed = 8'shff;
    if ($clog2(runtime_signed) != 8)
      $fatal(1, "runtime narrow signed argument is wrong");
    h = new;
    if (!h.randomize() || h.v != 64)
      $fatal(1, "hierarchical constant was lost");
    cp64 = new;
    if (!cp64.randomize() with { v == $clog2(N); } || cp64.v != 6)
      $fatal(1, "constant came from the wrong specialization");
    cp = new;
    ce = new;
    if (!cp.randomize() with { v == $clog2(N); } || cp.v != 3)
      $fatal(1, "class parameter lost to caller parameter");
    if (!ce.randomize() with { v == $clog2(N); } || ce.v != 3)
      $fatal(1, "class enum lost to caller parameter");
    if (!cp.randomize() with { v == $clog2(local::N); } || cp.v != 6)
      $fatal(1, "local:: constant did not use caller scope");
    if (!cp.randomize() with (v) { v == $clog2(N); } || cp.v != 6)
      $fatal(1, "with identifier list did not limit target lookup");
    if ($clog2(8'shff) != 8 || $clog2(1'sb1) != 0 || $clog2(16'sh8000) != 15)
      $fatal(1, "ordinary clog2 narrow signed argument is wrong");

    // 20 draws must ALL satisfy the band. One stray draw fails the test.
    for (int i = 0; i < 20; i++) begin
      if (!b.randomize()) begin
        $display("FAILED: banded.randomize() returned 0 on draw %0d", i);
        errors += 1;
      end else if (b.v < 3 || b.v > 6) begin
        $display("FAILED: draw %0d gave v=%0d, outside [3,6]", i, b.v);
        errors += 1;
      end
    end

    for (int i = 0; i < 20; i++) begin
      if (!m.randomize()) begin
        $display("FAILED: minus_one.randomize() returned 0 on draw %0d", i);
        errors += 1;
      end else if (m.v > 5) begin
        $display("FAILED: draw %0d gave v=%0d, above 5", i, m.v);
        errors += 1;
      end
    end

    // Sanity: the folded values are what IEEE says they are.
    if ($clog2(64) !== 6) begin $display("FAILED: $clog2(64) != 6");  errors += 1; end
    if ($clog2(1)  !== 0) begin $display("FAILED: $clog2(1) != 0");   errors += 1; end
    if ($clog2(0)  !== 0) begin $display("FAILED: $clog2(0) != 0");   errors += 1; end
    if ($clog2(65) !== 7) begin $display("FAILED: $clog2(65) != 7");  errors += 1; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d error(s)", errors);
  end

endmodule
