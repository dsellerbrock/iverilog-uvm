// The symbol-search cache must not survive NetScope::set_signal_alias():
// each array-manipulation-method `with` clause (IEEE 1800-2017 7.12.4)
// temporarily rebinds its iterator name (default "item") to a fresh
// per-clause net directly in the enclosing scope's signal map, then
// restores whatever was bound there before. A resolution of "item"
// cached from one `with` clause must not be reused by a second,
// unrelated `with` clause in the SAME enclosing scope that happens to
// use the same default iterator name -- especially the call form
// item.index()/item.index(1), which looks the resolved net up in a
// context stack keyed by exact identity and fails outright (rather
// than silently returning a wrong value) when handed a stale net.
//
// Reduced from tests/g10_iter_index_test.sv, which this reproduces:
// two `with` clauses using the call form, back to back, on plain
// queues (not classes), so this exercises the elaborate.cc path
// directly.
module main;
  int iq[$];
  int r1, r2;
  initial begin
    iq.push_back(5); iq.push_back(0); iq.push_back(7);
    r1 = iq.sum with (item.index());
    r2 = iq.sum with (item.index(1));
    if (r1 !== 3 || r2 !== 3) begin
      $display("FAILED r1=%0d r2=%0d", r1, r2);
      $finish;
    end
    $display("PASSED");
  end
endmodule
