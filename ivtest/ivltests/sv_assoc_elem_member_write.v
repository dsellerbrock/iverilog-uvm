// M4B-9: member write into an associative-array element of an unpacked struct.
// A write to a not-yet-present element (`a[key].field = ...`, and part-selects
// / compound variants) was silently dropped: the l-value load pushed a
// discarded default object because the element type was not recorded on the
// assoc signal, so the missing element was never materialized/inserted. The
// object-backed queue/assoc signal now records its element class type (like a
// dynamic array), and the l-value load get-or-CREATES the element. Reading a
// non-existent element still does NOT create it. IEEE 1800-2017 7.8
// (associative arrays), 7.2.1 (struct member). Self-checking.
module sv_assoc_elem_member_write;
  typedef struct { bit [31:0] d; bit [7:0] t; } cell_t;
  int errors = 0;
  initial begin
    cell_t a[string];
    cell_t ai[int];

    // Whole-member write into a not-yet-present element.
    a["x"].d = 32'hFFFFFFFF;
    if (a["x"].d !== 32'hFFFFFFFF) begin $display("FAIL whole: %h", a["x"].d); errors++; end

    // Part-select write into an element member.
    a["x"].d[7:0] = 8'h00;
    if (a["x"].d !== 32'hFFFFFF00) begin $display("FAIL part: %h", a["x"].d); errors++; end

    // Two members of the same element persist independently.
    a["y"].d = 32'hAABBCCDD;
    a["y"].t = 8'hEE;
    if (a["y"].d !== 32'hAABBCCDD || a["y"].t !== 8'hEE) begin
      $display("FAIL two-member: d=%h t=%h", a["y"].d, a["y"].t); errors++; end

    // Compound assignment into a not-yet-present element.
    a["z"].d += 32'h5;
    if (a["z"].d !== 32'h5) begin $display("FAIL compound: %h", a["z"].d); errors++; end

    // Integer key.
    ai[7].d = 32'hAA;
    if (ai[7].d !== 32'hAA) begin $display("FAIL int-key: %h", ai[7].d); errors++; end

    // Reading a non-existent element must NOT create it.
    if (a["never"].d !== 0) begin $display("FAIL read-default"); errors++; end
    if (a.exists("never")) begin $display("FAIL read created element"); errors++; end

    // Exactly the written string keys exist: x, y, z (not "never").
    if (a.num() !== 3) begin $display("FAIL num=%0d exp 3", a.num()); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
