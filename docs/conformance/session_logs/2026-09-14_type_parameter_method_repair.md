# Type-parameter-qualified method repair (in progress)

Base: local `db7d2bf01`. This repair follows the failed L53–L62 broad qualification; it does not replace the last broadly qualified baseline `c686a4781`.

## Trigger and required behavior

Unmodified UVM 2020.3.2 fails on `LIBTYPE::add_typewide_sequence`. Class type parameters must resolve to the actual specialization, execute the selected method, and preserve inherited method lookup. IEEE 1800-2017 and 1800-2023 remain separate validation modes.

The class-scope rules of IEEE 1800-2023 section 8.23 permit static member access outside the class hierarchy and superclass member access from a derived class. An unrelated caller cannot invoke a nonstatic method without an object; a valid superclass call must retain its implicit `this`. Static calling contexts must diagnose the absence of an object rather than assert internally.

## Independent evidence and review

Root evidence is in `evidence/uvm-release-regression-assessment/root-method-controls/`.

The intermediate `pre-static-rejection.json` replay records stable installed hashes and separate edition results: specialization isolation, inherited static functions, and package/object/hierarchical dispatch pass; missing-method and nonclass receivers reject. An unrelated nonstatic call is incorrectly accepted, and the legal superclass call compiles but loses its object. Emitted VVP explicitly passes `%null` to the superclass method. These findings were sent back to the implementation worker before integration.

`static_context.sv` additionally checks that a derived static function cannot use a nonexistent implicit object. Final frozen replay and permanent regression registration remain required. No completed release qualification is claimed.

## Next release work

Old UVM releases also require real function-valued constraint evaluation. The implementation must evaluate functions against current object state before solving and preserve constraint modes and virtual dispatch. It must not accept an ignored declaration by making `constraint_mode` a no-op.

`semantic/virtual-state.sv` fails in both editions because the inherited constraint is ignored. Its direct virtual-call control passes in both editions, isolating the missing constraint evaluation. Existing state-change, mode/unsatisfiability, and exact UVM-expression reducers remain required. For the UVM conjunction with sequence count 5, legal kinds are 2 through 4; zero is forbidden by the first item.

Status: implementation and focused review in progress; not integrated or broadly qualified.

## Receiver repair replay

`root-method-controls/static-context-review.json` records stable installed hashes
and 14/14 passing independent checks across 2017 and 2023. Unrelated nonstatic
and static-context calls reject; valid superclass, specialization, and ordinary
dispatch controls execute correctly. This is focused intermediate validation;
permanent registration, worker freeze, and selected release smoke remain pending.

`root-method-controls/task-and-function-review.json` extends the same stable
candidate to 18/18 checks, adding delayed task variants for specialization and
superclass dispatch. Compiler SHA256: `9aeecc24a155e260161a05a77a381bc2c9e456ec6b36a46bb8aa8348f60d5acb`;
VVP target: `48ee3f6609c7c4c1da28572388c8b0d356631eb7dcdd8fd9da55aecfd96d2b58`;
runtime: `65baa472d97e06f56ae30a22a51250adfa9f13404f9ab6ccb0dc96fef44d0488`.
Negative logs were inspected to confirm missing-method, nonclass, and receiver
diagnostics rather than an unrelated parser failure or internal abort.

## Frozen validation and integration readiness

The worker froze the reviewed implementation with the hashes above. Permanent
legacy tests pass 5/5 (`type-parameter-l63/final3-legacy.log`) and paired JSON
tests pass 10/10 (`final2-json.log`). Four invalid receiver cases have separate
fixtures; the masking combined negative was removed. Nine existing nearby
lookup tests pass (`root-neighbors.log`), including package, specialized static
containers, bare generic and typedef diagnostics, and inherited parameter calls.

The unchanged UVM 2020.3.2 release smoke now compiles and executes successfully:
`root-release-smoke/result.json`, compile exit 0, runtime exit 0,
`UVM_RELEASE_SMOKE_PASSED`, and zero UVM warnings/errors/fatals. The compile log
contains only the DPI export C generation note. This replays the existing
`-g2012` smoke and does not establish full release or IEEE conformance.

Final diff review and whitespace check pass. Local integration follows; no
remote publication is authorized by this checkpoint. Old-release function-valued
constraints and corrected broad qualification remain outstanding.

Local semantic integration: `f57a08a78` (fast-forward onto local main).
