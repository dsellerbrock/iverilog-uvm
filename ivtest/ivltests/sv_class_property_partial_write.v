// M1B-5: partial write (bit-select, part-select, indexed part-select, and
// packed-struct member) to a class PROPERTY, with both constant and run-time
// offsets. Formerly a silent miscompile (selects clobbered the whole property)
// and a hard crash (struct-member write). IEEE 1800-2017 7.4.6 (bit/part
// selects), 7.2.1 (packed struct member), 8.3 (class props). Self-checking.
module sv_class_property_partial_write;
  class R; logic [7:0] v; endclass
  class W; logic [15:0] m; endclass
  typedef struct packed { logic [3:0] hi, lo; } b_t;
  class Reg; b_t val; endclass

  int errors = 0;
  initial begin
    automatic R r = new;
    automatic W w = new;
    automatic Reg rg = new;

    // Constant bit/part selects.
    r.v = 8'hFF; r.v[3:0] = 4'h0;
    if (r.v !== 8'hF0) begin $display("FAIL low part: v=%h exp f0", r.v); errors++; end
    r.v = 8'h00; r.v[7:4] = 4'hA;
    if (r.v !== 8'hA0) begin $display("FAIL high part: v=%h exp a0", r.v); errors++; end
    r.v = 8'h00; r.v[0] = 1'b1; r.v[7] = 1'b1;
    if (r.v !== 8'h81) begin $display("FAIL bit ends: v=%h exp 81", r.v); errors++; end

    // Run-time single-bit offset.
    w.m = 0;
    for (int i = 0; i < 16; i += 2) w.m[i] = 1'b1;
    if (w.m !== 16'h5555) begin $display("FAIL var-bit: m=%h exp 5555", w.m); errors++; end

    // Run-time indexed part-select (ascending +: and descending -:).
    w.m = 0;
    for (int i = 0; i < 4; i++) w.m[i*4 +: 4] = i[3:0];
    if (w.m !== 16'h3210) begin $display("FAIL var+: m=%h exp 3210", w.m); errors++; end
    w.m = 0;
    for (int i = 0; i < 4; i++) w.m[i*4+3 -: 4] = (i+1);
    if (w.m !== 16'h4321) begin $display("FAIL var-: m=%h exp 4321", w.m); errors++; end

    // Packed-struct member write into a class property (was a crash).
    rg.val = 8'h00; rg.val.hi = 4'hA;
    if (rg.val !== 8'hA0) begin $display("FAIL struct hi: val=%h exp a0", rg.val); errors++; end
    rg.val.lo = 4'h5;
    if (rg.val !== 8'hA5) begin $display("FAIL struct lo: val=%h exp a5", rg.val); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
