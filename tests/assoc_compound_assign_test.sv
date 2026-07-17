// Regression: compound assignment (++, +=, -=, ...) on an associative-array
// element. The compressed-store code generator had no l-value *read* path
// for an associative element, so a local assoc corrupted the runtime object
// stack (crash) and a class-member assoc silently dropped the store (value
// unchanged). UVM's uvm_report_server severity counters are exactly this
// shape (int m_severity_count[uvm_severity]; incr does m[sev]++), which left
// UVM_ERROR/UVM_WARNING counts stuck at 0. Fixed by expanding a[k] op= rv
// into the plain store a[k] = a[k] op rv at elaboration.
//
// Prints "PASS" only if every sub-check holds.
module top;

  typedef enum {SEV_INFO, SEV_WARN, SEV_ERR} sev_e;

  // local associative arrays (int key and enum key)
  int  lc [int];
  int  le [sev_e];

  // class-member associative arrays (the UVM shape)
  class Counter;
    int m [sev_e];
    function void incr(sev_e s); m[s]++;        endfunction
    function void add (sev_e s, int v); m[s]+=v; endfunction
    function int  get (sev_e s); return m[s];   endfunction
  endclass

  initial begin
    bit ok = 1;

    // --- local, int key: ++ and += ---
    lc[7]++; lc[7]++; lc[7] += 5;              // 0 -> 1 -> 2 -> 7
    if (lc[7] !== 7) begin ok = 0; $display("FAIL local int lc[7]=%0d exp 7", lc[7]); end

    // --- local, enum key ---
    le[SEV_WARN]++; le[SEV_WARN]++;            // 0 -> 2
    if (le[SEV_WARN] !== 2) begin ok = 0; $display("FAIL local enum=%0d exp 2", le[SEV_WARN]); end

    // --- class-member, enum key: ++ (auto-vivify from default 0) ---
    begin
      Counter c = new;
      c.incr(SEV_ERR); c.incr(SEV_ERR); c.incr(SEV_ERR);   // 0 -> 3
      c.add(SEV_WARN, 10); c.add(SEV_WARN, 5);             // 0 -> 15
      if (c.get(SEV_ERR)  !== 3)  begin ok = 0; $display("FAIL member err=%0d exp 3",  c.get(SEV_ERR)); end
      if (c.get(SEV_WARN) !== 15) begin ok = 0; $display("FAIL member warn=%0d exp 15", c.get(SEV_WARN)); end
    end

    if (ok) $display("PASS: assoc compound assign (local+member, ++/+=)");
    $finish;
  end
endmodule
