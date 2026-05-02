// Phase 63b: enum literals declared inside a procedural block must
// be visible at use sites in the same block.
//
// Pre-fix: `typedef enum {RED, GREEN, BLUE} c_t; c_t c = GREEN;` inside
// an `initial begin ... end` failed with
//   Unable to bind wire/reg/memory `GREEN' (compile-progress: unresolved reference)
// because PBlock::elaborate_scope didn't call elaborate_scope_enumerations
// on the block's enum_sets.
`timescale 1ns/1ps

module top;
  initial begin
    typedef enum { RED, GREEN, BLUE } color_t;
    color_t c;
    int sum = 0;
    c = GREEN;
    if (c !== 1) $fatal(1, "FAIL/T1: c=%0d expected 1", c);
    if (c.name() != "GREEN") $fatal(1, "FAIL/T2: c.name='%s'", c.name());
    c = BLUE;
    if (c !== 2) $fatal(1, "FAIL/T3: c=%0d expected 2", c);
    // Iterate via .first/.next
    c = c.first();
    while (1) begin
      sum += c;
      if (c == c.last()) break;
      c = c.next();
    end
    if (sum !== (0+1+2)) $fatal(1, "FAIL/T4: sum=%0d", sum);
    $display("PASS: enum literals in procedural block scope");
    $finish;
  end
endmodule
