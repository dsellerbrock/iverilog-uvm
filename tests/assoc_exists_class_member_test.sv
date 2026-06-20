// Regression: associative-array exists() on a CLASS-MEMBER (property) assoc must
// return a 1-bit boolean (0 or 1), not all-ones, in a wider result context.
//
// The object-path helpers (aa_exists_vec/str/obj in vvp/vthread.cc) built the
// result as `vvp_vector4_t(wid, BIT4_1)` when the key was present, which fills
// ALL `wid` bits.  For a present key whose exists() result is used in an
// int/32-bit context, this yielded 0xffffffff (= -1) instead of 1.  A local
// (signal-path) assoc was unaffected (aa_exists_signal set only bit 0).
//
// This is the OpenTitan tl_monitor case:
//   tl_seq_item pending_a_req[bit [SourceWidth-1:0]];
//   `DV_CHECK_EQ_FATAL(pending_a_req.exists(cloned_req.a_source), 0)
// which fatally fired with actual=4294967295 when a source was pending.

module top;
  class item;
    rand bit [7:0] a_source;
  endclass

  class monitor;
    // class-member (property) associative array, value = class handle
    item pending[bit [7:0]];

    function int chk(item o);           // int (32-bit) result context
      return pending.exists(o.a_source);
    endfunction
    function void add(item o);
      pending[o.a_source] = o;
    endfunction
  endclass

  initial begin
    monitor m;
    item a, b;
    int errors = 0;
    m = new(); a = new(); b = new();
    a.a_source = 8'h3;
    b.a_source = 8'h7;
    m.add(a);

    // present key must be exactly 1 (not -1 / 0xffffffff)
    if (m.chk(a) !== 1) begin
      $display("FAIL: exists(present) = %0d / 0x%08h (want 1)", m.chk(a), m.chk(a));
      errors++;
    end
    // absent key must be 0
    if (m.chk(b) !== 0) begin
      $display("FAIL: exists(absent) = %0d (want 0)", m.chk(b));
      errors++;
    end
    // the OT comparison context
    if ((m.chk(a) == 0) != 0) begin
      $display("FAIL: (exists(present) == 0) should be false");
      errors++;
    end

    if (errors == 0) $display("PASS");
    else $display("assoc_exists_class_member_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule
