// A `foreach' selector prefix (IEEE 1800-2017/2023 12.7.3: an
// index-bracket identifier that already names a variable declared in
// an enclosing scope acts as a fixed selector, not a fresh loop
// variable) into a NESTED ASSOCIATIVE array must not silently produce
// wrong results. Confirmed independently: slang (--std 1800-2017)
// accepts all three forms below (bare-identifier `m_changed_sev[id][msg]',
// literal `m["a"][msg]', and an undotted `m[key][msg]' with a plain
// variable key), 0 errors -- so the parser rejecting them outright
// would be wrong. But every one of them, once accepted, reached a
// shared elaboration path (PForeach::elaborate_signal_array_ /
// elaborate_foreach_target_expr_) that wraps the WHOLE outer array in
// a NetESignal and hands it to elaborate_assoc_array_ unmodified --
// the selector is never consulted at all. A real, discriminating
// runtime check (two outer keys with disjoint inner key sets) shows
// this silently iterates the array's OWN (outer) keys instead of the
// selected sub-array's, rather than raising any diagnostic.
//
// Real, unmodified OpenTitan DV source relies on exactly this shape
// (hw/dv/sv/dv_utils/dv_report_catcher.sv: `foreach
// (m_changed_sev[id][msg])' over a `uvm_severity
// m_changed_sev[string][string]' where `id' is already a local
// variable -- see DISCOVERED_DEBT.md DD-040).
//
// Until the selector is correctly threaded through as a runtime
// lookup key, the construct is accepted syntactically and refused at
// elaboration with a focused sorry: rather than running with silently
// wrong results.
module main;
  int m[string][string];

  initial begin
    string id;
    id = "a";
    m["a"]["x"] = 1;
    foreach (m[id][msg]) begin
      $display(msg);
    end
  end
endmodule
