// M1B-3 tracked silent miscompile: a class property whose type is a
// TYPE PARAMETER bound to a QUEUE is mistyped as `int`/`logic` at access
// time, so the queue is unusable (its methods are silently dropped).
//
// IEEE 1800-2017 references: 6.20.3 (type parameters), 7.10 (queues), 8.3
// (parameterized classes). A property `T value;` in `box#(T)` specialized
// with a queue type argument must behave as a queue.
//
// STATUS: FIXED (M1B-3a). Root cause was an elaboration-ORDER bug, not a
// queue- or type-specific one: the method-target path
// (`elaborate_nested_method_target_property_task_` in elaborate.cc) looked
// the property up with property_idx_from_name(), which returns -1 when the
// specialization's property has not yet been committed (properties are
// declared on demand). The call was then mis-dropped as an "unknown task"
// and the aggregate silently stayed empty. Both the queue push_back path
// and the darray/assoc method paths hit this (indexing worked because it
// goes through the NetEProperty expression path, which already forces the
// declaration). Fixed by calling ensure_property_decl() on the specialized
// class first, matching the expression/index path. Regression test:
// ivtest/ivltests/sv_typeparm_aggregate_property.v.
//
// Historical context: this is the general form of the bug that the
// UVM-specific hack in net_expr.cc
// (`infer_indexed_property_type_fallback_`, hardcoded to `uvm_shared`/
// `value`/`T`) works around — `uvm_shared#(uvm_resource_base[$])` is
// exactly this queue-typed-type-parameter shape.
//
// SCOPE (empirically bisected, ivl at HEAD):
//   * Queue type argument      -> BROKEN (this file).
//   * Dynamic-array type arg    -> works  (`T value` = `int[]`  usable).
//   * Associative-array type arg-> works  (`T value` = `int[string]` usable).
//   * Concrete (non-parameter) queue property `int value[$]` -> works.
//
// ROOT CAUSE (bisected, site not yet pinpointed):
//   * The specialization cache key IS distinct and correct:
//       `...|O|queue of netvector_t:bool signed[31:0]`
//     (verified with IVL_SPEC_KEY_TRACE) — no specialization collision.
//   * The property IS committed with the correct queue type
//       (netclass set_property use_base = IVL_VT_QUEUE) — verified in
//       netclass_t::ensure_property_decl.
//   * Yet `$typename(b.value)` reports `logic` and `b.value.push_back(...)`
//     resolves to "unknown task" — so the defect is in ACCESS-SITE type
//     derivation for a queue-typed type-parameter property, which yields
//     an integer view instead of the committed queue. Dynamic/assoc arrays
//     do not hit this, so the gap is queue-specific in the access path.
//
// A safe fix needs the exact access-site divergence located (queue vs
// darray) plus full UVM/ivtest/dual-run validation, since the same path
// carries the UVM `uvm_shared` usage; it is deliberately NOT rushed here.

typedef int int_q_t[$];

class box #(type T = int);
  T value;
endclass

module typeparm_queue_property_mistyped;
  box#(int_q_t) b;
  initial begin
    b = new;
    // EXPECTED: value behaves as a queue -> size 2, q0=7.
    // ACTUAL:  "warning: Enable of unknown task ``b.value.push_back''"
    //          and the queue stays empty (size 0), because b.value is
    //          typed as int/logic at this access site.
    b.value.push_back(7);
    b.value.push_back(9);
    if (b.value.size() == 2 && b.value[0] == 7)
      $display("PASSED");
    else
      $display("FAILED (size=%0d, typename=%s)", b.value.size(), $typename(b.value));
    $finish;
  end
endmodule
