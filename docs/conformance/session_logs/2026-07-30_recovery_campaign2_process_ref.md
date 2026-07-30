# Recovery Campaign 2 — process/ref correctness (2026-07-30)

Scope: the ground-truth pass's process/reference P0 family. Three
reported findings turned out to be TWO defect families.

## Family 1: wrong-receiver virtual task dispatch (G65 + the vvp abort)

The reported "UVM task-phase hook executes twice per component" (G65)
and "racing arithmetic aborts the runtime" (vvp_vector4_t::add assert,
vvp_net.cc:1450) were ONE defect with two symptoms, reproduced by a
13-line pure-SV test:

- An override of a virtual method that omits the `virtual` keyword is
  implicitly virtual (IEEE 1800-2017 8.20), but the flag only recorded
  an explicit keyword, so codegen emitted a NON-dispatching call.
- Combined with the sole-override static binding in
  netclass.cc:resolve_method_call_scope (an empty-bodied base hook with
  exactly one override in the design binds the call to that override),
  EVERY receiver — including uvm_root and other non-overriding
  components — ran the user's override with a wrong-class `this`.
  Property reads through that `this` hit the wrong class layout: the
  reported abort, and (when widths happened to agree) silent
  wrong-object counting — the "twice per component" report.

Fix (commit d9b45d42): propagate implicit virtuality across the super
chain once supers are sig-elaborated, and make the flag STICKY across
deferred/specialized class re-elaboration (which used to clear it
back to the pform value). The sole-override binding stays, now always
guarded by /v runtime dispatch — uvm_root correctly runs the empty
base body while user components run their override exactly once
(verified at UVM level with run_phase AND main_phase, two components).

Removing the static binding outright was tried and REJECTED: UVM boot
relies on dozens of pure-virtual/sole-implementation call sites whose
generic dispatch plumbing is not yet trustworthy (that attempt
silently broke uvm_report_server processing; evidence retained in the
recovery dossier).

Discriminators: ivtest sv_class_implicit_virtual_dispatch (crashes
pre-fix with the exact reported assert), tests/phase_hook_count_test.sv
(UVM; aborts pre-fix).

## Family 2: ref-formal companion temporaries lose detached writes (R25)

Confirmed and closed for the addressed kinds (commit d13875d0): a ref
formal bound to an array element, class property, dynamic-array or
queue element actual is now a TRUE REFERENCE (tagged binding in
vvp_ref_signal_aa: %ref/bind/pr, %ref/bind/el, %ref/bind/w), not a
copy pair. Detached writes after the task returns land in the actual;
queue resize between bind and write is honoured; a property binding
holds the RECEIVER OBJECT and survives handle-variable reassignment.

Residual copy-pair fallbacks (string formals, struct members, nested
property paths, automatic-array words, associative-array elements) are
no longer silent: a per-call-site warning names the formal and exactly
what a detached write would lose. SUPPORTED WITH VERIFIED SCOPE, not
FULL.

Discriminators: ivtest sv_ref_arg_inside_storage_bind and
sv_ref_arg_inside_storage_adversarial (each fails 7 ways pre-fix).

## Also observed, tracked, NOT closed here

- ~50-130 "queue operation on a null queue value was skipped" warnings
  in every UVM run (pre-existing; dropped mutations inside UVM
  machinery — likely static-property container initialization order).
  Campaign 3 territory.
- Implicitly-static block-scope variable with a non-constant
  initializer runs the initializer once and warns; IEEE 6.21 wants an
  explicit lifetime keyword (should be a hard error). Deliberately not
  changed in this campaign (blast radius unassessed).
- regress-sv.list registers br1015b as `normal` but the construct is
  refused (regress-ivl1.list correctly has it as CE) — pre-existing
  list inconsistency, visible only when running regress-sv.list
  directly; the gate's default sweep is unaffected.
