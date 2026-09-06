// Regression for vpi/v2009_enum.c:207, compare_value_eequal(). The
// next()/prev()/name() enum methods fetch the enum variable and each
// enum-constant candidate with vpiObjTypeVal and then compare the two
// s_vpi_value results. For a 1-bit-wide enum variable, vpiObjTypeVal
// resolves the variable to vpiScalarVal, while an enum constant's natural
// format resolves to vpiIntVal (2-state base type) or vpiVectorVal
// (4-state base type) -- a format pair compare_value_eequal() did not
// recognize, tripping its "formats are: 6 vs 5" (or 9 vs 5) assertion on
// any 1-bit enum .name()/.next()/.prev() call.
module top;

  bit failed = 1'b0;

  `define check(x) \
    if (!(x)) begin \
      $display("FAILED at line %0d", `__LINE__); \
      failed = 1'b1; \
    end

  // Triggering case: a 1-bit-wide, 2-state (bit) enum. This is the exact
  // combination that hit "formats are: 6 vs 5" (vpiIntVal vs vpiScalarVal).
  typedef enum bit { OFF = 1'b0, ON = 1'b1 } toggle2_t;
  toggle2_t t2;

  // Same shape but 4-state (logic), which hit the vpiVectorVal-vs-vpiScalarVal
  // ("9 vs 5") variant, and exercises legal X/Z scalar values.
  typedef enum logic { LO = 1'b0, HI = 1'b1 } toggle4_t;
  toggle4_t t4;

  // Nonmatching-value control: a wider 2-state enum with an assignable
  // in-width value that is not a member, exercising the "not found"
  // fill_handle_with_init()/empty-name path through the same compare.
  typedef enum bit [1:0] { A2 = 2'd0, B2 = 2'd1, C2 = 2'd2 } wide2_t;
  wide2_t w2;

  // Controls for the pre-existing, already-working paths.
  typedef enum int { RED = 0, GREEN = 1, BLUE = 2 } color_t;          // vpiIntVal/vpiIntVal
  typedef enum bit [7:0] { P = 8'h01, Q = 8'h02, R = 8'h03 } byte_t;  // vpiVectorVal/vpiVectorVal
  color_t c;
  byte_t b;

  initial begin

    // --- 1-bit 2-state enum: legal 0/1 scalar values ---
    t2 = OFF;
    `check(t2.name() == "OFF")
    `check(t2.next() == ON)
    `check(t2.prev() == ON)   // only 2 members: prev wraps to the other one
    t2 = ON;
    `check(t2.name() == "ON")
    `check(t2.next() == OFF)  // wraps
    `check(t2.prev() == OFF)

    // --- 1-bit 4-state enum: legal 0/1 scalar values ---
    t4 = LO;
    `check(t4.name() == "LO")
    `check(t4.next() == HI)
    `check(t4.prev() == HI)
    t4 = HI;
    `check(t4.name() == "HI")
    `check(t4.next() == LO)
    `check(t4.prev() == LO)

    // --- 1-bit 4-state enum: legal X/Z scalar values (not in the list) ---
    t4 = toggle4_t'(1'bx);
    `check(t4.name() == "")
    `check(t4.next() === 1'bx)   // four-state base type: not-found fills X
    `check(t4.prev() === 1'bx)
    t4 = toggle4_t'(1'bz);
    `check(t4.name() == "")
    `check(t4.next() === 1'bx)
    `check(t4.prev() === 1'bx)

    // --- Nonmatching value control (2-state, wider than 1 bit) ---
    w2 = wide2_t'(2'd3);
    `check(w2.name() == "")
    `check(w2.next() === 2'd0)   // two-state base type: not-found fills 0
    `check(w2.prev() === 2'd0)
    w2 = B2;
    `check(w2.name() == "B2")
    `check(w2.next() == C2)
    `check(w2.prev() == A2)

    // --- Control: existing vpiIntVal/vpiIntVal path (int enum) ---
    c = GREEN;
    `check(c.name() == "GREEN")
    `check(c.next() == BLUE)
    `check(c.prev() == RED)

    // --- Control: existing vpiVectorVal/vpiVectorVal path (wide enum) ---
    b = Q;
    `check(b.name() == "Q")
    `check(b.next() == R)
    `check(b.prev() == P)

    if (!failed) $display("PASSED");
  end
endmodule
