// M1B-5: a PARTIAL write (bit-select, part-select, or packed-struct member)
// to a class PROPERTY was broken — a silent miscompile for the vector case
// and a hard runtime crash for the struct-member case. Read-back and whole-
// property writes were always correct; only the partial WRITE path was wrong.
//
// IEEE 1800-2017 references: 7.4.6 (bit/part selects), 7.2.1 (packed struct
// member access), 8.3 (class properties).
//
// STATUS: FIXED. This is a self-checking regression test.
//
// ORIGINAL SYMPTOMS (ivl before the fix):
//   (1) Bit/part-select write clobbered the WHOLE property (no RMW):
//         r.v = 8'hFF; r.v[3:0] = 4'h0;   // gave v==8'h00, expected 8'hF0
//       Codegen emitted `%store/prop/v 0, 8' (whole store) for a bit-select
//       l-value, and single-bit `r.v[i]' set an array word index that the
//       runtime mis-treated as an unpacked-array store (crash).
//   (2) Packed-struct member write CRASHED:
//         r.val.hi = 4'hA;   // vvp abort: pop_prop_val assert val.size()>=wid
//       Codegen DID emit `%store/prop/v/bits' (the RMW opcode) but with a
//       garbage r-value: NetAssign_::net_type() returned null for a class-
//       property part-select l-value, so expr_type() fell back to the class
//       handle's IVL_VT_CLASS and the assigned value elaborated as a
//       null-handle test. The runtime handler also lacked a vvp_cobject
//       branch (it read-modify-wrote only vvp_vinterface objects).
//
// ROOT CAUSE spanned three layers, all now fixed:
//   - elaboration (elab_lval.cc): a bit/part-select of a packed-vector class
//     property, and a packed-struct field of a class property, must call the
//     TYPED set_part() so the l-value reports the selected sub-vector's type
//     (not the enclosing class handle), and must use set_part (RMW) rather
//     than set_word (array index) or a whole-property store. Constant and
//     run-time offsets (bit-select, `+:', `-:') are canonicalized to an LSB-0
//     bit offset.
//   - codegen (tgt-vvp/stmt_assign.c): a constant part offset routes to the
//     `%store/prop/v/bits' RMW path; a run-time offset is evaluated into an
//     index register and routes to the new `%store/prop/v/bits/x' path.
//   - runtime (vvp/vthread.cc): of_STORE_PROP_V_BITS gained a vvp_cobject
//     read-modify-write branch, and of_STORE_PROP_V_BITSX applies the same
//     RMW at a register-supplied bit offset.
//
// Descending [hi:lo] packed vectors (the ubiquitous form, e.g. UVM's
// uvm_pack_bitstream_t) are fully supported for constant and variable
// offsets. A variable select into an ASCENDING [lo:hi] vector, or a
// multi-dimensional packed property, is loudly diagnosed (sorry) rather than
// silently miscompiled — see the negative test.

module class_property_partial_write;
  class R; logic [7:0] v; endclass
  typedef struct packed { logic [3:0] hi, lo; } b_t;
  class Reg; b_t val; endclass

  class W; logic [15:0] m; endclass

  int errors = 0;
  initial begin
    automatic R r = new;
    automatic Reg rr = new;
    automatic W w = new;

    // (1) low-nibble part-select preserves the high nibble.
    r.v = 8'hFF;
    r.v[3:0] = 4'h0;
    if (r.v !== 8'hF0) begin $display("FAIL low part: v=%h exp f0", r.v); errors++; end

    // (2) high-nibble part-select preserves the low nibble.
    r.v = 8'h00;
    r.v[7:4] = 4'hA;
    if (r.v !== 8'hA0) begin $display("FAIL high part: v=%h exp a0", r.v); errors++; end

    // (3) single-bit selects at both ends.
    r.v = 8'h00;
    r.v[0] = 1'b1; r.v[7] = 1'b1;
    if (r.v !== 8'h81) begin $display("FAIL bit ends: v=%h exp 81", r.v); errors++; end

    // (4) sequential partial writes accumulate correctly.
    r.v = 8'hFF;
    r.v[3:0] = 4'h0; r.v[7:4] = 4'h5;
    if (r.v !== 8'h50) begin $display("FAIL combo: v=%h exp 50", r.v); errors++; end

    // (5) run-time single-bit offset.
    w.m = 0;
    for (int i = 0; i < 16; i += 2) w.m[i] = 1'b1;
    if (w.m !== 16'h5555) begin $display("FAIL var-bit: m=%h exp 5555", w.m); errors++; end

    // (6) run-time indexed part-selects (+: and -:), like UVM's packer.
    w.m = 0;
    for (int i = 0; i < 4; i++) w.m[i*4 +: 4] = i[3:0];
    if (w.m !== 16'h3210) begin $display("FAIL var+: m=%h exp 3210", w.m); errors++; end
    w.m = 0;
    for (int i = 0; i < 4; i++) w.m[i*4+3 -: 4] = (i+1);
    if (w.m !== 16'h4321) begin $display("FAIL var-: m=%h exp 4321", w.m); errors++; end

    // (7) packed-struct member write into a class property (was a crash).
    rr.val = 8'h00;
    rr.val.hi = 4'hA;
    if (rr.val !== 8'hA0) begin $display("FAIL struct hi: val=%h exp a0", rr.val); errors++; end
    rr.val.lo = 4'h5;
    if (rr.val !== 8'hA5) begin $display("FAIL struct lo: val=%h exp a5", rr.val); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
