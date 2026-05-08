# sva-temporal branch — real SVA semantics

Branch from `development @ 998ea709e` (post-chapter-16-closure, sv-tests
1022/1027).  The 16 chapter-16 SVA tests currently passing as
"compile-progress fallback" silently drop their assertions; the
sv-tests harness only catches `:assert: (False)` strings in output, so
silent drops register as PASS.  Goal: replace silent drops with real
semantics one operator family at a time.

## What's already in iverilog (C2, Phase 62f)

- `assert property (@(clk) [disable iff (rst)] A)` lowers to
  `always @(clk) if (!rst && !A) $error;` — basic case works.
- `assert property (@(clk) A |-> B)` lowers to
  `always @(clk) if (A && !B) $error;` — overlapping implication works.
- `K_property`, `K_endproperty`, `K_sequence`, `K_endsequence` are token-defined
  but no declaration grammar uses them.
- `property_expr` has rules for `and`, `or`, `intersect`, `throughout`,
  `within`, `iff`, `##N` — but they all collapse to plain `&&`/keep-one-side.
- `K_SEQ_CC` (`##N`) parses but drops `N`.

## What silently fails today

- `|=>` parses as op_type=2 then `body = new PNoop;` — dropped.
- `sequence ... endsequence` declaration → syntax error → compile-progress.
- `property ... endproperty` declaration → syntax error → compile-progress.
- `$past`, `$rose`, `$fell`, `$stable`, `$changed` → not recognized,
  parse as unknown system function with implementation stub returning 0/X.
- `[*N]`, `[->N]`, `[=N]` — only `[*]` and `[+]` parse.
- Multi-clock sequences, property locals, `expect`, `s_eventually`, `nexttime` —
  all unsupported.

## Phase plan (sequenced, each with validation tests)

Each phase adds one or more `tests/sva_*_test.sv` regression tests with:
- a known-pass case (property holds, no error fires)
- a known-fail case (property doesn't hold, error fires)
That proves real semantics — not just "no-op compiled cleanly".

### S1 — real `|=>` (next-cycle implication)
Currently silently dropped.  Lower `@(clk) A |=> B` to:
```
always @(clk) begin
  reg ant_prev = 0;
  if (!disable && ant_prev && !B) $error(...);
  ant_prev <= A;
end
```
Use a synthesized name-mangled per-assertion register.

### S2 — sampled-value functions ($past, $rose, $fell, $stable, $changed)
Add in elab_expr.cc as system function recognizers.  At elaboration:
- `$past(x, N)` (N defaults to 1): synthesize a length-N+1 shift register
  clocked by the enclosing `always @(clk)` block, return the tail
- `$rose(x)`: `x & ~$past(x)` (1-bit) or its MSB-bit form for vectors
- `$fell(x)`: `~x & $past(x)`
- `$stable(x)`: `x === $past(x)`
- `$changed(x)`: `x !== $past(x)`

The history register is per-(signal, clock) — share when same signal
sampled at the same clock by multiple assertions.

### S3 — `sequence...endsequence` and `property...endproperty` declarations
Add grammar rules:
```
sequence_declaration : K_sequence IDENTIFIER ';' sequence_expr ';' K_endsequence
property_declaration : K_property IDENTIFIER ';' property_spec ';' K_endproperty
```
Store as named entities in the enclosing scope.  At property_expr
elaboration, allow IDENTIFIER to resolve to a named sequence/property
and inline-substitute.

### S4 — real `##N` delay
`A ##N B` lowers to: at clock T A holds, at clock T+N B holds.
Synthesize a shift register that captures A's value at each clock,
and check B when the bit shifted out N cycles later was 1.

### S5 — real `and`, `or`, `intersect`, `throughout`
Currently approximated.  These need an NFA-style sequence matcher.
Defer if S1-S4 unlock the bulk of the chapter-16 tests.

### S6 — property-local variables
`property foo; logic [7:0] x = 0; ... endproperty`
Synthesize as auto-scope variables sampled into the always block.

### S7 — multi-clock sequences, range repetition, edge operators
`[*N:M]`, `s_eventually`, `nexttime`, `until`.  Niche.  Defer.

## Honest validation gate

Before claiming "Phase S1 done", a test like:
```sv
module top;
  bit clk = 0; bit a, b;
  always #5 clk = ~clk;
  assert property (@(posedge clk) a |=> b)
    else $display(":assert: False  // |=> failed");

  initial begin
    a = 1; #10 b = 0;        // a holds, next cycle b is 0 → ASSERT MUST FIRE
    #20;
    $display(":assert: True   // saw the failure correctly");
    $finish;
  end
endmodule
```

…must print `:assert: False`.  Today it silently passes (no output).

Each phase's tests go in `iverilog/tests/sva_<feature>_pass.sv` and
`iverilog/tests/sva_<feature>_fail.sv`.  The fail variants must actually
fire the error.

## Compile-progress fallbacks: explicit non-goal

Phase 62f's silent-drop pattern must NOT survive into S1+.  Every
construct must either be implemented or surface a hard error.  The
no-op fallback is what gives us the 16 false-positive PASSes in
sv-tests today; we're not adding more of those.
