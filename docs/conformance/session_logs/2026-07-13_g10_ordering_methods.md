# Session log — 2026-07-13 (third target): 7.12.2 ordering methods

Engineering target: the IEEE 1800-2017 7.12.2 array ordering methods
(sort, rsort, reverse, shuffle; plus the unique statement forms that
share their machinery).  UVM calls `.sort()` in six places —
uvm_phase_hopper (`succ_q.sort with (item.get_full_name())`),
uvm_root (`m_time_settings.sort() with (item.offset)`),
uvm_cmdline_report (3× `sort() with (item.get_full_name())`),
uvm_registry (`m__type_aliases.sort()`).

## Starting evidence (reduced probes)

The Phase 63b implementation covered signal receivers, but had three
latent defects, all SILENT:

1. **Instance-property receivers no-op'd**: `r.iq.sort()` left the
   queue unmodified — tgt-vvp/vvp_process.c had an explicit
   "silently skip rather than warning" branch for non-signal
   receivers.  (Statics and locals worked, which is why UVM's own six
   sites appeared fine.)
2. **String sort keys truncated to 32 bits**: the with-clause key
   build always evaluated the predicate as vec4 and stored 32-bit
   keys; `qsort_with_keys_dispatch_` extracted `int32_t`.  Keys
   sharing a 4-byte prefix compared equal — the exact
   `sort() with (item.get_full_name())` shape mis-sorted
   ("uvm_test_top.env.zebra/alpha/mike" kept insertion order).
   Real keys were similarly collapsed through vector4_to_value.
3. **Shared iterator nets**: the sort_with elaboration still used the
   find_signal-and-reuse iterator scheme whose type-poisoning was
   fixed on the expression side a session earlier.

## Implemented

- **Runtime** (vvp/vthread.cc, no new opcodes):
  `qsort_with_keys_helper_` and `qunique_keys_helper_` generalized
  over the key type (`<ELEM, KEY>`); the dispatchers inspect the KEYS
  array's runtime type and extract `vector<string>`,
  `vector<double>`, or `vector<int32_t>` accordingly (7.12.2: "the
  relational operators shall be defined for the type of the
  expression").  rsort uses `keys[b] < keys[a]` so only operator< is
  required.
- **Elaboration** (elaborate.cc PCallTask::elaborate_method_):
  - all four emit sites (reverse, plain sort/rsort/unique, sort_with
    family, shuffle) allocate a hidden container-typed receiver net
    when obj_expr is not a NetESignal and append it as a trailing
    argument (`make_ordering_method_recv_net_`);
  - the keys queue element type now follows the elaborated with
    expression (string / real / signed-32);
  - fresh uniquely-named iterator net per call, bound to the
    user-visible name only during predicate elaboration via
    `NetScope::set_signal_alias`.
- **Codegen** (tgt-vvp/vvp_process.c): the silent-skip branch is
  replaced by the hidden-recv-net pattern (evaluate receiver object
  once, `%store/obj` the handle, run `%qsort`/`%qsort/keys`/... on
  the hidden net — in-place reorder reaches the property because
  containers are held by handle); the key-build loop emits
  `draw_eval_string` + `%store/qb/str` or `draw_eval_real` +
  `%store/qb/r` for string/real predicates, and the keys queue is
  created with the matching element encoding.  A remaining
  unsupported receiver shape now warns once instead of silently
  skipping.

## Verified (permanent test `tests/g10_ordering_methods_test.sv`, 28 checks)

LRM 7.12.2 examples (int sort/rsort/reverse/shuffle, string-element
sort/reverse); dynamic-array receivers; instance-property receivers
for all five methods (internal, external); string keys longer than 32
bits with a common prefix, both sort and rsort; real keys; int keys
on object elements in the paren-less-with form; iterator isolation
across element types in one scope.

## Regression evidence

Recorded in the checkpoint commit message (UVM suite, bundled ivtest,
negative 6/6, focused g10/g68/g69/m6/g12 re-runs).
