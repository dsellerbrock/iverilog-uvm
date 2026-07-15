# 2026-07-15 — M12: VPI SystemVerilog object model (PR #76)

Directive: "Begin M12 and do not stop until fully closed — complete
and full implementation, all iterations in this session."

Before this milestone the VPI layer covered classic Verilog objects
well but SystemVerilog objects only partially: dynamic-array element
WRITES crashed the simulator (assertion in vvp_vector4_t::setarray —
the target vector was never sized), queues exposed only their size,
associative arrays had no runtime support at all, class objects were
opaque (no member access), interfaces masqueraded as vpiModule,
modports did not exist, package-qualified lookup was unparsed,
value-change callbacks rejected every SV variable type, and several
vpi_get/format defaults crashed via assert(0) instead of diagnosing.

## M12-1: SV variables, containers, class members

- **Crash fix**: vpi_put_value(vpiIntVal) on any dynamic-array
  element asserted; the vector is now sized before setarray.
- **Queues** share the full dynamic-array element machinery
  (__vpiQueueVar : __vpiDarrayVar): vpi_handle_by_index, vpiMember
  iteration, element read/write. vpiArrayType is detected from the
  LIVE object (vpiDynamicArray / vpiQueueArray / vpiAssocArray).
- **Associative arrays**: vpiSize, vpiArrayType, and positional
  element iteration in key order (string keys, then object keys,
  then vector keys — vvp_assoc_base::peek_entry). Writing assoc
  elements through VPI is a loud sorry (keys are not positions).
- **Class variables**: vpi_iterate(vpiMember) yields one stable
  handle per property (vpiName/vpiFullName, type code decoded from
  the property type — vpiIntVar/vpiByteVar/vpiShortIntVar/
  vpiLongIntVar/vpiBitVar/vpiLogicVar/vpiRealVar/vpiStringVar/
  vpiClassVar/vpiArrayVar — width, signedness). Member values read
  AND write through the live object; handles stay valid across
  object re-assignment and report nil when the variable is null.
- **Dotted descent**: vpi_handle_by_name("top.obj.prop") resolves
  class-variable members (one level; nested object members are a
  recorded corner).
- vpi_iterate(vpiVariables) now includes string/class/array vars;
  container elements also iterate under vpiMember.
- **Value-change callbacks on SV variables**: string variables fire
  on every value change; class/container variables fire on handle
  assignment. The callback list lives on the signal functor (these
  nets have no vvp_net_fil_t filter); the value payload is fetched
  through the callback's own object handle. In-place container/
  property mutation does not fire (recorded corner).
- **Crash hardening**: assert(0)/assert(false) defaults in the SV
  vpi_get and value-format paths are now loud non-fatal diagnostics
  (vpiUndefined / vpiSuppressVal).

## M12-2: scopes — interfaces, modports, packages

- **Interface instances report vpiInterface** (601): NetScope's
  existing is_interface flag plumbs through t-dll
  (ivl_scope_is_interface, exported in ivl.def) to a new
  `.scope interface` directive and vpiScopeInterface runtime class.
  Interface scopes traverse under vpiInternalScope; vpip_module
  treats interface/program scopes as module-like so signals in
  top-level interfaces do not walk off the root.
- **Modports are VPI objects** (vpiModport, new code 603): interface
  scopes carry their modport names (copied from the pform at scope
  elaboration), emitted as `.modport "name"` directives, iterable
  via vpi_iterate(vpiModport, iface) with vpiName/vpiFullName and
  vpiInterface/vpiScope relations. Per-signal directions stay
  compile-time (recorded).
- **Package-qualified vpi_handle_by_name**: "pkg::item" resolves the
  package among root instances then the item within (dotted tails
  recurse). Packages iterate from the root (existing).
- Generate scopes were already vpiGenScope; vpiGenScopeArray
  grouping is a recorded corner.

## M12-3: callbacks, force/release

- SV value-change callbacks landed with M12-1 (above). All the
  classic cb reasons were already implemented (cbValueChange,
  cbReadOnlySynch, cbReadWriteSynch, cbAtStartOfSimTime,
  cbAtEndOfSimTime, cbAfterDelay, cbEndOfCompile,
  cbStartOfSimulation, cbEndOfSimulation, cbNextSimTime).
- Force/release via vpi_put_value flags works on whole vector and
  real signals (existing); bit/part-select force via VPI remains the
  existing loud sorry (recorded corner); cbForce/cbRelease callback
  reasons are not dispatched (recorded corner).

## M12-4: covergroups (and assertions)

- **Covergroup types are VPI objects** (vpiCovergroup, new code
  605): vpi_iterate(vpiCovergroup, NULL) yields one handle per
  registered covergroup type with vpiName/vpiFullName, vpiSize (bin
  record count) and vpi_get_value returning the LIVE type coverage
  percentage (real) — wired to the M11 coverage service.
- **Assertions**: the M9 SVA engine synthesizes assertions into
  plain checker processes; no runtime assertion objects exist, so
  the assertion VPI API (vpiAssertion, cbAssertion*) is not
  implemented — vpi_iterate returns NULL (the defined "none"
  answer). Recorded corner; the IVL_COVERAGE_REPORT/$ivl end-of-sim
  reporting and the SVA fail/pass action blocks are the supported
  observation mechanisms.

## Handle lifetime disposition

Handles are semi-permanent by design: vpi_free_object is a no-op for
all but iterators and array words (leak-by-design, stable pointers —
member handles are owned by their class variable and remain valid
across object re-assignment; container word handles are owned by the
variable). No reference counting (recorded). The valgrind-only bulk
teardown remains development-mode.

## Tests

Three permanent gold-file regressions in the repo-bundled ivtest
(run by CI via .github/test.sh → vpi_reg.pl):

- ivtest/vpi/m12_sv_objects.{c,v} — typed SV variables, string
  read/write + value-change callback firing (including on a VPI
  write), darray kind/size/element read+write, queue elements,
  assoc positional iteration, class member iteration and by-name
  member read/write (visible from SV), vpiVariables completeness.
- ivtest/vpi/m12_sv_scopes.{c,v} — vpiInterface type, modport
  iteration, interface signal access, pkg::var lookup, root package
  iteration.
- ivtest/vpi/m12_sv_coverage.{c,v} — covergroup handle iteration
  with live type-coverage values across samples.

## M12 recorded corners (at close)

- Nested class-member descent by name (obj.obj2.x) — one level
  implemented; member handles of class type are not themselves
  navigable.
- Value-change callbacks do not fire on IN-PLACE container element
  or class property mutation (only handle assignment); string
  variables fire on every change.
- Writing associative-array elements through VPI (loud sorry).
- Modport SIGNAL DIRECTIONS via VPI (names only); vpiGenScopeArray
  grouping; vpiInterfaceArray.
- Bit/part-select force/release via VPI (existing loud sorry);
  cbForce/cbRelease/cbStmt/cbTchkViolation reasons.
- Assertion VPI object model (vpiAssertion, cbAssertion* — no
  runtime assertion identities in the synthesized-checker design).
- Covergroup VPI drill-down below the covergroup handle (per-item /
  per-bin objects) — the IVL_COVERAGE_REPORT text serialization
  carries that detail.
- vpi_free_object is a no-op for non-iterator handles
  (leak-by-design, stable handles).
- struct/union/enum-var specific VPI type codes (enum vars report
  their base vector type).

## Promotion evidence

Recorded below after the full sweeps.
