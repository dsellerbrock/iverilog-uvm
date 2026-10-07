# Multi-boundary `disable iff` qualification — 2026-10-07

## Result

IEEE 1800-2017/2023 §16.13.1 multiclocked sequence chains accept legal `##0`
and `##1` clock-flow changes. An explicit `disable iff` applies asynchronously
to the whole property; it does not inherit a clock from the chain. The
N-domain lowering now supports this for its fixed boolean-chain subset. A
reset transition clears every in-flight handoff and pending verdict, and each
clock domain suppresses work while the condition remains true.

The paired regression verifies three distinct cases: a reset pulse between
the second and third domain clocks cancels a live obligation; a reset held
over a source-clock edge suppresses a new attempt; and a later attempt after
release reaches its expected failure. A no-reset control confirms both
non-disabled obligations fail. The feature remains bounded to shapes already
accepted by the N-domain fixed-chain lowering; this is not full clause-16
qualification.

## Reproducer and implementation

The permanent reducers are
`ivtest/ivltests/sv_assert_multiclock_disable_chain.v` and its strict-2023
counterpart. Before this change, Fix31 rejected both with:

```text
`disable iff' composed with more than one clock-flow change in the same sequence
```

`pform.cc` now clones the explicit condition for each domain, gates domain
work, and installs one asynchronous abort process that clears handoff
counters, local pipeline stages, and pending pass/failure dispatch counts.
Cumulative cover results and sampled-value histories are retained.

## Validation

The configured source build completed with `make -j4` and `make install`.

Strict focused multiclock-control checks passed in both editions:

- JSON/VVP: 22/22.
- Legacy: 22/22.

Commands, run from `ivtest/`:

```bash
PATH=../local-install/bin:$PATH perl vvp_reg.pl regress-sv_assert_multiclock_fixed_control-focus-legacy.list
PATH=../local-install/bin:$PATH python3 vvp_reg.py regress-sv_assert_multiclock_fixed_control-focus-vvp.list
```

No broad regression, OpenTitan corpus, or Caliptra run was needed.

Source-built image SHA-256:

| Artifact | SHA-256 |
|---|---|
| `iverilog` | `36167f4671b3cb3616dae40e800be83a238e10301cc4516d27c69ca98d486e15` |
| `ivl` | `83c226da5d43699fdf676e606ba3ffe5a860a6de66a4d72162307bdbc69c6776` |
| `vvp` | `158fb79e1624083da370d5a176bf85f3ef96e01b91e4c75279af8a68309638b1` |
| `vvp.tgt` | `404a3620fc341d4746a77d7f89086505ccbbf35a7a95832b896ab32b3138dfb1` |
