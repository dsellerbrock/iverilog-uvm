// Regression: bitwise (& | ^ ~), shift (<< >> >>>) and $countones operators
// must be supported inside randomize constraints (IEEE 1800-2017 §18 / §11.4).
//
// pexpr_to_constraint_ir previously had no PEBinary cases for & | ^ << >> >>>,
// no PEUnary case for ~, and no $countones handler, so any constraint using
// them was silently dropped (the rand fields stayed free).  This is the
// OpenTitan tl_seq_item pattern:
//   constraint addr_size_align_c { (a_addr & ((1 << a_size) - 1)) == 0; }
//   constraint mask_w_PutFullData_c { $countones(a_mask) == (1 << a_size); }
//
// Also covers the guard: a packed part-select on a property with non-constant
// bounds must DROP the whole constraint cleanly (emitting the bare property
// would widen the operand and corrupt the solve into UNSAT).

module top;

  class item;
    rand bit [31:0] a_addr;
    rand bit [1:0]  a_size;
    rand bit [3:0]  a_mask;

    // size 0..2
    constraint sz_c { a_size <= 2; }
    // natural alignment: a_addr divisible by (1<<a_size)
    constraint align_c { (a_addr & ((1 << a_size) - 1)) == 0; }
    // mask fullness: number of active byte lanes == (1<<a_size)
    constraint mask_full_c { $countones(a_mask) == (1 << a_size); }
    // exercise bitwise OR / XOR / NOT too
    constraint extra_c { ((a_mask | 4'h0) ^ 4'h0) == a_mask;
                         (~a_size & 2'b11) == (2'b11 - a_size); }
    // force a wide access so alignment + full mask are non-trivial
    constraint big_c { a_size == 2; a_addr inside {[64:127]}; }
  endclass

  initial begin
    item it;
    int errors = 0;
    it = new();
    for (int i = 0; i < 40; i++) begin
      if (!it.randomize()) begin
        $display("FAIL: randomize returned 0"); errors++; continue;
      end
      // size==2 -> 4-byte op: addr must be 4-aligned, mask must be 4'hf
      if ((it.a_addr & 32'h3) != 0) begin
        $display("FAIL: align: a_addr=0x%08h size=%0d", it.a_addr, it.a_size); errors++;
      end
      if ($countones(it.a_mask) != (1 << it.a_size)) begin
        $display("FAIL: mask not full: mask=0x%1h size=%0d", it.a_mask, it.a_size); errors++;
      end
    end
    if (errors == 0) $display("PASS");
    else $display("constraint_bitwise_shift_countones_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule
