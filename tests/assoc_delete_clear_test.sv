// Regression: the no-argument associative-array delete() (clear-all) form must
// empty the array. This is the OpenTitan tl_monitor #8b root cause:
// tl_monitor::pending_a_req.delete() (called on reset to drop aborted
// transactions) was a silent no-op, so stale entries survived a reset and
// later collided with a reused a_source -> DV_CHECK_EQ_FATAL.
//
// Root cause: aa.delete() (no key) generated %delete/o/obj (property) or
// %delete/obj (signal), which cast the receiver to vvp_queue and did nothing
// for an associative array (a vvp_assoc_base). Fixed with a new %aa/clear
// opcode emitted for the no-arg assoc-compat case.
//
// Covers three forms: explicit-handle class property, implicit-this member
// inside a method (the OT form), and a module-level signal associative array.

class item;
  int x;
endclass

class mon;
  item pending[int];

  function void add(int src);
    item it = new();
    it.x = src;
    pending[src] = it;
  endfunction

  // implicit-this clear-all, mirrors tl_monitor::pending_a_req.delete()
  function void clear_self();
    pending.delete();
  endfunction
endclass

module top;
  // module-level (signal) associative array
  int sig_aa[int];

  initial begin
    mon m = new();
    int errors = 0;

    // --- class property, explicit handle ---
    m.add(0);
    m.add(7);
    if (m.pending.size() != 2) begin
      $display("FAIL: size after 2 adds == %0d (expected 2)", m.pending.size()); errors++;
    end
    m.pending.delete();
    if (m.pending.size() != 0) begin
      $display("FAIL: prop explicit delete() size == %0d (expected 0)", m.pending.size()); errors++;
    end
    if (m.pending.exists(0) || m.pending.exists(7)) begin
      $display("FAIL: prop explicit delete() left keys"); errors++;
    end

    // --- class property, implicit-this inside a method (OT form) ---
    m.add(3);
    m.clear_self();
    if (m.pending.size() != 0) begin
      $display("FAIL: prop implicit-this delete() size == %0d (expected 0)", m.pending.size()); errors++;
    end

    // re-add after clear must behave consistently (no stale growth)
    m.add(9);
    if (m.pending.size() != 1 || !m.pending.exists(9)) begin
      $display("FAIL: re-add after clear inconsistent (size=%0d)", m.pending.size()); errors++;
    end

    // --- module-level signal associative array ---
    sig_aa[1] = 11;
    sig_aa[2] = 22;
    if (sig_aa.size() != 2) begin
      $display("FAIL: sig size after 2 adds == %0d (expected 2)", sig_aa.size()); errors++;
    end
    sig_aa.delete();
    if (sig_aa.size() != 0) begin
      $display("FAIL: signal delete() size == %0d (expected 0)", sig_aa.size()); errors++;
    end
    if (sig_aa.exists(1) || sig_aa.exists(2)) begin
      $display("FAIL: signal delete() left keys"); errors++;
    end

    if (errors == 0) $display("PASS");
    else $display("assoc_delete_clear_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule
