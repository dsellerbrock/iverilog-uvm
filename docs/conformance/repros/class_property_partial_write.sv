// M1B-4/M4B-3 audit finding: a PARTIAL write (bit-select or packed-struct
// member) to a class PROPERTY is broken — a silent miscompile, and a hard
// crash for the struct-member form. Read-back and whole-property writes are
// correct; only the partial WRITE path is wrong.
//
// IEEE 1800-2017 references: 7.4.6 (bit/part selects), 7.2.1 (packed struct
// member access), 8.3 (class properties).
//
// STATUS: characterized, NOT yet fixed. High-priority correctness/robustness.
//
// SYMPTOMS (ivl at HEAD):
//   (1) Bit-select write clobbers the WHOLE property (no read-modify-write):
//         class R; logic [7:0] v; endclass
//         r.v = 8'hFF; r.v[3:0] = 4'h0;   // -> v == 8'h00, expected 8'hF0
//       The codegen emits `%store/prop/v 0, 8' (a whole-property store) for a
//       bit-select l-value instead of a bit-offset RMW.
//   (2) Packed-struct member write CRASHES:
//         typedef struct packed { logic [3:0] hi, lo; } b_t;
//         class Reg; b_t val; endclass
//         r.val.hi = 4'hA;   // vvp abort: pop_prop_val assert val.size()>=wid
//       The codegen DOES emit `%store/prop/v/bits' (bit-offset RMW), but with
//       a garbage r-value (a null-test flag rather than the assigned value),
//       AND the runtime handler of_STORE_PROP_V_BITS (vvp/vthread.cc) only
//       implements the VIF case — for a plain class object (vvp_cobject) it
//       drops the store entirely.
//
// ROOT CAUSE spans three layers:
//   - elaboration: the r-value of a struct-member class-property l-value is
//     mis-derived (comes out as a null-test expression);
//   - codegen (tgt-vvp/stmt_assign.c): a bit-select l-value of a logic
//     property takes the whole-property `%store/prop/v' path instead of the
//     `%store/prop/v/bits' RMW path;
//   - runtime (vvp/vthread.cc of_STORE_PROP_V_BITS): no vvp_cobject branch —
//     it read-modify-writes only vvp_vinterface objects.
//
// This is why UVM (which writes whole class properties and uses methods, not
// partial-writes into class-property bit fields) stays green while this
// fundamental operation is broken. The fix is a focused correctness arc
// across the three layers with full revalidation.

module class_property_partial_write;
  class R; logic [7:0] v; endclass
  int errors = 0;
  initial begin
    automatic R r = new;
    r.v = 8'hFF;
    r.v[3:0] = 4'h0;             // EXPECTED v == 8'hF0
    if (r.v !== 8'hF0) begin
      $display("FAILED bit-select write: v=%0h expected f0", r.v); errors++;
    end
    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
