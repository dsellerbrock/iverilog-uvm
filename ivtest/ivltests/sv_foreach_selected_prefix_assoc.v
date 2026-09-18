// A `foreach' selector prefix (IEEE 1800-2017/2023 12.7.3: an
// index-bracket identifier that already names a variable declared in
// an enclosing scope acts as a fixed selector, not a fresh loop
// variable) into a NESTED ASSOCIATIVE array must correctly select the
// sub-array named by the selector, for both a variable selector
// (`m[id][msg]') and a literal/constant one (`m["a"][msg]'). Confirmed
// independently: slang (--std 1800-2017) accepts both forms, 0 errors.
//
// Real, unmodified OpenTitan DV source relies on exactly the variable
// form (hw/dv/sv/dv_utils/dv_report_catcher.sv: `foreach
// (m_changed_sev[id][msg])' over a `uvm_severity
// m_changed_sev[string][string]' where `id' is already a local
// variable -- see DISCOVERED_DEBT.md DD-040).
//
// This is a real, discriminating-population runtime check (two outer
// keys with disjoint inner key sets): it fails if the selector is
// ignored and the loop iterates the array's OWN (outer) keys instead
// of the selected sub-array's.
module main;
  int m[string][string];
  int fails;

  initial begin
    string id;
    id = "a";
    m["a"]["x"] = 1;
    m["a"]["y"] = 2;
    m["b"]["z"] = 3;

    begin
      int seen;
      seen = 0;
      foreach (m[id][msg]) begin
        seen++;
        if (msg != "x" && msg != "y") fails++;
      end
      if (seen != 2) fails++;
    end

    begin
      int seen;
      seen = 0;
      foreach (m["a"][msg2]) begin
        seen++;
        if (msg2 != "x" && msg2 != "y") fails++;
      end
      if (seen != 2) fails++;
    end

    if (fails == 0) $display("PASSED");
    else $display("FAILED, fails=%0d", fails);
    $finish;
  end
endmodule
