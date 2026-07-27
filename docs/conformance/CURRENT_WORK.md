# CURRENT WORK — continuation state

This is the short resume state. `ROADMAP.md` is the living tracker,
`iverilog_ieee1800_uvm_manifesto.md` carries policy, and dated technical
narratives live in `session_logs/`.

## Resume state — 2026-07-26

Branch: `codex/access-aggregate-boundary-closure`, based on the merge of
PR #121 (`9ca10bd18`).

The access and aggregate boundary campaign is closed:

- **M4B-15:** a whole fixed unpacked-array member of an unpacked struct now
  crosses ordinary SystemVerilog and DPI open-array formals with its element
  type, values, dimensions, declared bounds, index translation, and
  output/inout copyback intact. The covered receivers are direct structs,
  structs in class properties and runtime containers, and direct/virtual
  interfaces for ordinary SV calls.
- **M1C-7 / R16:** `$cast` destinations now include local fixed, dynamic,
  queue, and associative-array elements plus elements behind nested
  receivers. Successful downcasts store, failed casts preserve the
  destination, and task-form failures diagnose.
- **M1C-7:** `foreach (u[constant].nested.array[i])` retains the selected
  instance-array prefix and iterates/updates the target. Local, unindexed
  hierarchical, class-property, and virtual-interface controls remain clean.

The implementation materializes an inline fixed-array property as a typed
nested darray value. Declared-range metadata stays passive for ordinary
fixed-to-dynamic assignment and is activated only at an open-array formal,
so an ordinary dynamic array remains 0-based. SV array queries/`foreach` and
DPI H.10 accessors see the fixed actual's declared indices. Copyback uses the
aggregate property store.

Discriminating pre-fix evidence:

- the struct-member access matrix computed 0 instead of 806;
- the legal real-element open-array calls were rejected;
- the container `$cast` regression aborted in VVP;
- indexed-instance `foreach` loops silently read/wrote zero elements.

Final gates on this branch:

- focused SV access/aggregate matrix: pass;
- real-DPI `m4b_struct_array_member_open_test`: pass;
- `make check`: pass;
- negative suite: 61 passed, 0 failed;
- SVA dual-run: 36 passed, 0 failed;
- vendored ivtest: 3,217 total, exactly 44 expected failures and no
  failure-identity drift;
- bundled VPI: 92 passed, 0 failed;
- full UVM with real DPI: 226 passed, 0 failed, 0 skipped;
- installed/relocated `-uvm` frontend: all scenarios passed.

Detailed implementation and test evidence:
`session_logs/2026-07-26_access_aggregate_boundary_closure.md`.

Known neighboring gaps remain loud and outside this closed campaign:
method calls on queue members of unpacked structs, and direct
multidimensional arrays of instances (not represented by the compiler).

Resume from the priority-ordered open rows in `ROADMAP.md`; do not reopen
this campaign without a new discriminating reproducer.
