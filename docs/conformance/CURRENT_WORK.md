# CURRENT WORK — continuation state

This is the short resume state. `ROADMAP.md` is the living tracker,
`iverilog_ieee1800_uvm_manifesto.md` carries policy, and dated technical
narratives live in `session_logs/`.

## Resume state — 2026-07-28

Branch: `claude/ieee1800-closure-campaign-lqalye`, started fresh from
main and rebased onto `7136907`, which carries the merged PRs #125, #126
and #127. The previous PR on this branch (#121) is merged, so this is a
new pull request rather than a continuation of that one.

### Campaign 2 — whole aggregate value semantics

One missing primitive turned out to explain four separate symptoms. A
fixed unpacked array used where a container is wanted has marshaled its
words since M10-1 (`%load/arr/dar`); the **return trip did not exist**,
and each place it was needed failed differently:

| shape | what it did |
|---|---|
| `fa = da;` and `s.arr = da;` | assigned the **constant 0**, silently |
| `t(fa)` for `inout int q[]` | **aborted ivl** on legal input, even when the body only read the formal |
| `f(fa)` for `ref int q[]` | warned once, then silently left the caller's array alone |

The assignment case is the one worth remembering. `fa = da` is not
`type_compatible`, so it reached the compile-progress fallback in
`elab_and_eval` that substitutes a constant for an incompatible r-value
when the target looks vectorable — and an unpacked array's `cast_type`
is its ELEMENT type, so `int fa[3]` looked exactly that vectorable.

New `%store/arr/dar` is the inverse of `%load/arr/dar`, and all four
paths go through it. The 7.6 element-count rule is checked inside the
instruction, because a dynamic source has no size until it runs; a
mismatch reports and leaves the destination unchanged rather than
half-filling it.

The inbound direction is fixed for **real** elements too: the special
case meant to accept a fixed-array actual for an open-array formal asked
the EXPRESSION for its `netuarray_t`, but a signal expression's
`net_type()` is its element type, so the test never succeeded — integral
arrays slipped past on the vectorable fallback while real arrays took a
cast error.

Roadmap: M10-7 (done), M10-8 (the multidimensional boundary, open and
loud). Tests: `sv_whole_aggregate_value_copy`,
`sv_whole_aggregate_size_mismatch`.

**Verified, not assumed, on the way through:**

- DPI open arrays are complete — re-probed with a fresh C model, not an
  existing test: `svDimensions`/`svSize`/`svLow`/`svHigh`/`svLeft`/
  `svRight`/`svIncrement` all report the **declared** range for
  ascending, descending and non-zero-based actuals, elements read
  through `svGetArrElemPtr1`, and an `inout` formal writes back.
  GitHub issue #45 closed on that evidence.
- Multidimensional open arrays are **not** as done as M10-1's label
  said, but the gap is narrower than it first looked. A 2-D struct/class
  MEMBER works both ways: `%prop/arr/dar` materializes a **nested**
  object — a `vvp_darray_object` per declared dimension — and
  `%store/prop/arr/dar` walks it back. A plain 2-D variable is an
  elaboration error. Recorded as M10-8.

### Next frontier

**Finish M10-8: a plain 2-D variable as an open-array actual.** I had
this filed as "nested containers are a subsystem"; an experiment showed
that is only half right, and the useful half is much closer than that.

A 2-D unpacked SIGNAL is already flat at runtime — `int m[2][3]` emits
`.array/2s "m", 5 0, 31 0`, six words — and the nested representation
the formal wants already exists and is already built for members.
Opening both elaboration gates by hand gets a 2-D actual all the way to
the runtime, where it reads zero with
`get_word(vvp_object_t) not implemented for vvp_darray_atom<int>`:
`%load/arr/dar` built a flat array where the formal iterates a nested
one.

So what is missing is the signal-side twins of
`fixed_prop_materialize_`/`fixed_prop_copy_back_`, plus a way to carry
the declared dimension list — which lives in the `netuarray_t` at
elaboration and is absent from the flat signal — to the two
instructions. The operand slots are the real constraint: `vvp_code_s`
keeps `array` and `text` in one union, so the list cannot ride as a
string beside `OA_ARR_PTR`; it needs its own codespace table or a
push-dims instruction.

Both elaboration gates fail for the *same* reason, worth knowing before
starting: a signal expression's `net_type()` is its ELEMENT type, so
neither the `elab_and_eval` cast check nor the `PEIdent` context check
ever sees the `netuarray_t`. That is the third time this session that
accessor has been the root cause.

**Separately, and genuinely a subsystem:** `int d[][];` does not parse,
so nested dynamic arrays as *declared types* remain out of reach. That
is what R19 shares, and it is its own campaign.

### Truth pass — 2026-07-28

The five `Phase 7x` GitHub issues were probed item by item rather than
read. #43, #44, #45 and #47 are closed: #45 genuinely complete, the
other three obsolete as tracking units (their acceptance criterion,
"96+/98 regression", names a suite that no longer exists). #46
(performance) is deliberately left open and unre-labelled — its claims
are wall-clock measurements I did not reproduce, and closing it on the
strength of the others would be the sort of unvalidated label this pass
exists to remove.

Sixteen of the twenty-eight probed items were already done. The
survivors carry forward as R17–R23. One correction to my own first
reading: `a.reverse()` returning nothing is **not** a defect — 7.12.2
ordering methods return void, so the r-value spelling I probed with is
not legal SystemVerilog. The in-place form works.

### Gates

`make check`, the vendored ivtest name-diff, bundled VPI, the negative
suite, the SVA dual-run, the DPI subsystem and full UVM — see the pull
request for the run.

One regression was caught by the name-diff and fixed rather than
absorbed: the first cut refused a multidimensional copy-back outright,
which broke `sv_struct_array_member_open_arg` — a member destination had
been working all along through `%store/prop/arr/dar`. The new path now
takes over **only** a plain word-array signal destination, which is the
one shape that had no instruction.
