// M4B-6: partial write (bit-select, part-select, indexed part-select, with
// constant AND run-time offsets) into a packed-vector member of a plain
// UNPACKED struct variable, including nested structs. Formerly a silent
// miscompile (the whole member was clobbered), the sibling of the class-
// property bug M1B-5. Unpacked-struct members are cobject-backed and share
// the same read-modify-write path. IEEE 1800-2017 7.2.1 (struct member
// access), 7.4.6 (bit/part selects). Self-checking.
module sv_struct_member_partial_write;
  typedef struct { bit [31:0] byte_en; bit [31:0] data; } bus_t;
  typedef struct { bit [15:0] a; logic [7:0] b; } inner_t;
  typedef struct { inner_t inr; int tag; } outer_t;

  int errors = 0;
  initial begin
    automatic bus_t s;
    automatic outer_t o;
    automatic bit be [4] = '{1,0,1,1};

    // Run-time single-bit into a struct member.
    s.byte_en = 0;
    for (int z = 0; z < 4; z++) s.byte_en[z] = be[z];
    if (s.byte_en !== 32'h0000000d) begin $display("FAIL byte_en=%h exp 0d", s.byte_en); errors++; end

    // Run-time indexed part-select (UVM packer / adapter pattern).
    s.data = 0;
    for (int i = 0; i < 4; i++) s.data[i*8 +: 8] = i;
    if (s.data !== 32'h03020100) begin $display("FAIL data=%h exp 03020100", s.data); errors++; end

    // Constant part-select preserves the rest of the member.
    s.byte_en = 32'hFFFFFFFF; s.byte_en[7:0] = 8'h00;
    if (s.byte_en !== 32'hFFFFFF00) begin $display("FAIL const-part=%h exp ffffff00", s.byte_en); errors++; end

    // Nested unpacked struct member, run-time +: and -:.
    o.inr.a = 0;
    for (int i = 0; i < 4; i++) o.inr.a[i*4 +: 4] = i;
    if (o.inr.a !== 16'h3210) begin $display("FAIL nested a=%h exp 3210", o.inr.a); errors++; end
    o.inr.b = 0;
    for (int i = 0; i < 2; i++) o.inr.b[i*4+3 -: 4] = (i+1);
    if (o.inr.b !== 8'h21) begin $display("FAIL nested b=%h exp 21", o.inr.b); errors++; end

    // Constant single-bit into a nested member.
    o.inr.b = 8'h00; o.inr.b[0] = 1'b1; o.inr.b[7] = 1'b1;
    if (o.inr.b !== 8'h81) begin $display("FAIL nested bit=%h exp 81", o.inr.b); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
