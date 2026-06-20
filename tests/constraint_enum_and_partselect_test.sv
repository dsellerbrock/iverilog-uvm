// Regression: class constraints must support (a) compile-time constant operands
// that are parameters / enum labels (not rand properties), and (b) part-selects
// of a rand property whose bounds are parameter expressions (not bare numerals).
//
// pexpr_to_constraint_ir previously dropped both forms:
//   - a non-property identifier with value_slots==null returned "" (so a
//     parameter / enum label operand made the whole relation collapse);
//   - a part-select `a_addr[SizeWidth-1:0]` could not fold its bounds and was
//     dropped (emitting the bare property would corrupt the solve into UNSAT).
// Both are now resolved using the constraint's scope (elab_and_eval).
//
// This is the OpenTitan tl_seq_item well-formedness set (a_opcode is a plain
// bit field there, compared against the package enum label PutFullData):
//   a_opcode == PutFullData -> $countones(a_mask) == (1 << a_size);
//   (a_mask & ~(((1 << (1 << a_size)) - 1) << a_addr[SizeWidth-1:0])) == 0;

module top;

  localparam bit [2:0] PUT_FULL = 3'd0;

  class item;
    localparam int SZW = 2;
    rand bit [31:0] a_addr;
    rand bit [1:0]  a_size;
    rand bit [3:0]  a_mask;
    rand bit [2:0]  a_opcode;

    // parameter operand in a class constraint
    constraint op_c   { a_opcode == PUT_FULL; }
    constraint sz_c   { a_size <= 2; }
    // mask fullness gated by the parameter comparison
    constraint full_c { a_opcode == PUT_FULL -> ($countones(a_mask) == (1 << a_size)); }
    // parameter-bounded part-select of a rand property
    constraint lane_c { (a_mask & ~(((1 << (1 << a_size)) - 1) << a_addr[SZW-1:0])) == 0; }
    // alignment
    constraint align_c { (a_addr & ((1 << a_size) - 1)) == 0; }
    // make it non-trivial
    constraint big_c  { a_size == 2; a_addr inside {[256:511]}; }
  endclass

  initial begin
    item it;
    int errors = 0;
    it = new();
    for (int i = 0; i < 40; i++) begin
      if (!it.randomize()) begin
        $display("FAIL: randomize returned 0"); errors++; continue;
      end
      if (it.a_opcode != PUT_FULL) begin
        $display("FAIL: parameter-operand constraint dropped: a_opcode=%0d", it.a_opcode); errors++;
      end
      // size==2 (4-byte) PutFull: full mask == 4'hf, addr 4-aligned
      if (it.a_mask !== 4'hf) begin
        $display("FAIL: mask full constraint dropped: mask=0x%1h size=%0d", it.a_mask, it.a_size); errors++;
      end
      if ((it.a_addr & 32'h3) != 0) begin
        $display("FAIL: alignment dropped: addr=0x%08h", it.a_addr); errors++;
      end
    end
    if (errors == 0) $display("PASS");
    else $display("constraint_enum_and_partselect_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule
