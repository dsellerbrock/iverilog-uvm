# OpenTitan HMAC VVP concatenation initial delivery (2026-08-24)

## Scope and root cause

After the HMAC dynamic-array slice compile blocker was fixed, the unmodified
OpenTitan smoke reached `tlul_rsp_intg_gen.sv:82` but fired `RspZero_A` at
0 ps. The packed response is assembled through nested VVP concatenations. A
`.concat` node intentionally initializes its accumulator to Z so an untouched
portion of a partial-vector input stays Z, but it previously published after
the first input changed that accumulator. Its parent could therefore observe
the child before every connected child port had delivered.

The exact packed-struct reducer produced three callbacks with the prior
runtime. Callback one exposed `rsp_intg=zzzzzzz`, although the source drives
that field to zero. The fixed runtime produces two callbacks and both already
contain `rsp_intg=0000000`.

## Runtime correction

The ordinary and strength-aware concat constructors now receive the parsed
connected-input count. The bytecode loader rejects a count outside 1–4 before
construction or shifting; the constructors retain that range assertion as an
internal invariant. Each stores `(1U << argc) - 1U` and maintains a monotonic
seen-port mask.

For vec4, every delivery updates the Z accumulator first, then marks its port
and gates scheduling. Completion forces the first publication even when the
last delivery is legitimate Z and changes no bit; later unchanged values are
still suppressed. A first completion after simulation startup is forwarded
immediately so later processes in the same Active iteration see the continuous
result. Pre-simulation completion and later updates preserve the existing
`net_` event coalescing. Concat8 applies the same per-port gate and retains its
existing post-readiness scheduling. Readiness is not derived from widths or
bit coverage: a connected `.part/pv` port is ready after its partial delivery,
while omitted zero-repeat operands and trailing zero width slots create no
required port.

## Permanent regression and validation

`sv_concat_initial_port_delivery` is registered in both legacy and JSON/VVP
harnesses. One explicit top combines:

- the exact OpenTitan-shaped nested packed-struct initialization and
  `RspZero_A` callback oracle;
- a legitimate all-Z child followed by two known-value updates;
- `.part/pv` delivery whose untouched upper bits remain Z;
- strength-aware `.concat8` initialization, force/update, and release;
- an anchored all-Z concat8 completion callback and a nested concat8 tree whose
  prior runtime emits two observable torn callbacks;
- a six-connected-input compiler-generated concat tree; and
- zero-repeat operand elision.

The generated image contains ordinary and strength-aware concat trees plus one
`.part/pv`. Running that same image gives the expected red/green split:

```text
prior runtime: rsp events=3 torn=1; concat8 tree events=3 torn=2; FAILED
fixed runtime: PASSED
```

Native ARM64 commands used the current worktree and the no-RSS-cap resource
runner. The serial full build and `make install` completed successfully. The
focused legacy result is 1/1 passed, and the focused JSON/VVP result is 2/2
passed including the existing `partsel_outside_expr` ordering regression. A
five-operand raw `.concat` plus `.concat8` image exits nonzero with two bounded
diagnostics instead of reaching an assertion or undefined shift. The permanent
`concat_malformed_arity.vvp` runtime fixture pins that loader boundary and its
exact two-error result. No OpenTitan file was modified.

The exact HMAC smoke no longer reports `RspZero_A` or UVM `BUILDERR`. With the
adjacent boolean-`dist` solver fix in this follow-on worktree it advances to
696084 ps, where a later scoreboard `is_idle` mismatch is the next frontier.
This is not a whole-HMAC pass.
